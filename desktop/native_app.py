"""Ventana nativa para el cliente de escritorio StockGo."""
import base64
import json
import os
import secrets
import tkinter as tk
from io import BytesIO
from pathlib import Path
from tkinter import filedialog, messagebox, simpledialog, ttk
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from urllib.parse import urlsplit
from PIL import Image, ImageOps
CONFIG = Path(os.environ.get("APPDATA", Path.home())) / "StockGo" / "escritorio.json"
# Dirección comprobada del servicio central en Render. Puede sobrescribirse para
# pruebas con STOCKGO_API_URL, pero los usuarios finales no deben escribirla.
DEFAULT_API = os.environ.get("STOCKGO_API_URL", "https://stockgo-api-demo.onrender.com").rstrip("/")
BG, WHITE, NAVY, BLUE, TEAL, MUTED, RED = "#F3F8FC", "#FFFFFF", "#10334B", "#087FC1", "#0FA6C9", "#587086", "#C84343"
class ApiError(Exception): pass
def money(value): return f"Q {float(value) / 100:,.2f}"
def webp_image(path):
    """Convierte una fotografía a WebP de hasta 10 KB antes de mandarla a la API."""
    try:
        with Image.open(path) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
            image.thumbnail((800, 800))
            quality, output = 78, BytesIO()
            while True:
                output.seek(0); output.truncate(0); image.save(output, format="WEBP", quality=quality, method=6)
                if output.tell() <= 10 * 1024: break
                if image.width <= 128 and image.height <= 128: raise ApiError("No fue posible reducir la imagen a 10 KB. Elige una fotografía más simple.")
                image = image.resize((max(128, int(image.width * .75)), max(128, int(image.height * .75))), Image.Resampling.LANCZOS)
                quality = max(40, quality - 8)
            return base64.b64encode(output.getvalue()).decode(), output.tell()
    except ApiError: raise
    except Exception as exc: raise ApiError("No se pudo convertir la imagen a WebP.") from exc
def parse_sg1(value):
    if not value.strip().startswith("SG1-"): raise ApiError("El código debe iniciar con SG1-.")
    try:
        code = value.strip()[4:]
        data = json.loads(base64.urlsafe_b64decode(code + "=" * (-len(code) % 4)).decode())
        url = data["url"].rstrip("/")
        if urlsplit(url).scheme != "https": raise ValueError("Solo se permiten códigos de StockGo Cloud por HTTPS.")
        return url, data["negocio"]
    except (ValueError, KeyError, UnicodeDecodeError) as exc: raise ApiError("El código de negocio no es válido.") from exc
class Api:
    def __init__(self, url="", code=""): self.url, self.code, self.token = url, code, ""
    def call(self, method, path, body=None):
        headers = {"Accept": "application/json", "Content-Type": "application/json"}
        if self.code: headers["X-StockGo-Code"] = self.code
        if self.token: headers["Authorization"] = "Bearer " + self.token
        request = Request(self.url + "/" + path.lstrip("/"), data=json.dumps(body).encode() if body is not None else None, headers=headers, method=method)
        try:
            with urlopen(request, timeout=20) as response: return json.loads(response.read().decode())
        except HTTPError as exc:
            try: detail = json.loads(exc.read().decode()).get("error")
            except (ValueError, UnicodeDecodeError): detail = None
            raise ApiError(detail or f"El servidor respondió {exc.code}.") from exc
        except (URLError, TimeoutError) as exc: raise ApiError("No se pudo conectar a la nube.") from exc
class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("StockGo Escritorio"); self.geometry("1120x700"); self.minsize(940, 600); self.configure(bg=BG)
        self.api, self.user, self.products, self.cart = Api(), {}, [], []
        self.setup_style(); self.connect_screen()
    def setup_style(self):
        style = ttk.Style(self); style.theme_use("clam")
        style.configure("TFrame", background=BG); style.configure("Card.TFrame", background=WHITE)
        style.configure("TLabel", background=BG, foreground=NAVY); style.configure("Card.TLabel", background=WHITE, foreground=NAVY)
        style.configure("Title.TLabel", background=BG, foreground=NAVY, font=("Segoe UI Semibold", 24))
        style.configure("Hero.TLabel", background=NAVY, foreground="white", font=("Segoe UI Semibold", 26))
        style.configure("HeroSub.TLabel", background=NAVY, foreground="#C9E9F4")
        style.configure("Primary.TButton", background=BLUE, foreground="white", borderwidth=0, padding=(16, 10), font=("Segoe UI Semibold", 10))
        style.map("Primary.TButton", background=[("active", TEAL)])
        style.configure("Nav.TButton", background=NAVY, foreground="white", borderwidth=0, anchor="w", padding=(13, 10))
        style.map("Nav.TButton", background=[("active", "#1B5272")])
        style.configure("Treeview", rowheight=31, background=WHITE, fieldbackground=WHITE, foreground=NAVY)
        style.configure("Treeview.Heading", background="#E4F1F7", foreground=NAVY, font=("Segoe UI Semibold", 10))
    def clear(self):
        for child in self.winfo_children(): child.destroy()
    def card(self, parent, padding=24): return ttk.Frame(parent, style="Card.TFrame", padding=padding)
    def saved_code(self):
        try: return json.loads(CONFIG.read_text()).get("sg1", "")
        except (OSError, ValueError): return ""
    def remember(self, code):
        CONFIG.parent.mkdir(parents=True, exist_ok=True)
        CONFIG.write_text(json.dumps({"sg1": code, "url": self.api.url, "business": self.api.code}))
    def connect_screen(self):
        self.clear()
        root = tk.Frame(self, bg=BG, padx=46, pady=42); root.pack(fill="both", expand=True)
        shell = tk.Frame(root, bg=BG); shell.place(relx=.5, rely=.5, anchor="center", relwidth=.92, relheight=.82)
        hero = tk.Frame(shell, bg=NAVY, width=430, padx=42, pady=48); hero.pack(side="left", fill="both", expand=False); hero.pack_propagate(False)
        tk.Label(hero, text="▣", bg=BLUE, fg="white", font=("Segoe UI Symbol", 28), padx=14, pady=9).pack(anchor="w")
        tk.Label(hero, text="StockGo", bg=NAVY, fg="white", font=("Segoe UI Semibold", 30)).pack(anchor="w", pady=(26, 6))
        tk.Label(hero, text="Menos pendientes.\nMás control.", bg=NAVY, fg="white", justify="left", font=("Segoe UI Semibold", 27)).pack(anchor="w")
        tk.Label(hero, text="Todo tu inventario en un solo lugar.\nSimple, ordenado y siempre contigo.", bg=NAVY, fg="#C3DFD9", justify="left", font=("Segoe UI", 12)).pack(anchor="w", pady=(18, 26))
        for item in ("✓  Productos organizados", "✓  Acceso según tu rol", "✓  Información protegida en la nube"):
            tk.Label(hero, text=item, bg=NAVY, fg="white", anchor="w", font=("Segoe UI", 11)).pack(anchor="w", pady=7)
        right = tk.Frame(shell, bg=BG, padx=38); right.pack(side="left", fill="both", expand=True)
        box = self.card(right, 32); box.place(relx=.5, rely=.5, anchor="center", relwidth=.9)
        ttk.Label(box, text="Bienvenido de nuevo", style="Title.TLabel").pack(anchor="center")
        ttk.Label(box, text="El administrador entra con su negocio. El vendedor usa SG1 solo al vincularse.", style="Card.TLabel", wraplength=410).pack(anchor="center", pady=(6, 18))
        self.login_role = tk.StringVar(value="administrador")
        roles = ttk.Frame(box, style="Card.TFrame"); roles.pack(fill="x", pady=(0, 10))
        ttk.Radiobutton(roles, text="Administrador", value="administrador", variable=self.login_role).pack(side="left")
        ttk.Radiobutton(roles, text="Vendedor", value="vendedor", variable=self.login_role).pack(side="left", padx=18)
        self.business_login_row = ttk.Frame(box, style="Card.TFrame")
        ttk.Label(self.business_login_row, text="Nombre del negocio", style="Card.TLabel").pack(anchor="w")
        self.business_login = tk.StringVar(); ttk.Entry(self.business_login_row, textvariable=self.business_login).pack(fill="x", pady=(4, 12))
        self.sg_value = tk.StringVar(value=self.saved_code())
        self.code_login_row = ttk.Frame(box, style="Card.TFrame")
        ttk.Label(self.code_login_row, text="Código del negocio SG1", style="Card.TLabel").pack(anchor="w")
        field = ttk.Entry(self.code_login_row, textvariable=self.sg_value, font=("Consolas", 10)); field.pack(fill="x", pady=(4, 12)); field.focus()
        self.login_user, self.login_password = tk.StringVar(), tk.StringVar()
        self.login_user_widget = ttk.Label(box, text="Usuario", style="Card.TLabel"); self.login_user_widget.pack(anchor="w")
        ttk.Entry(box, textvariable=self.login_user).pack(fill="x", pady=(4, 12))
        ttk.Label(box, text="Contraseña", style="Card.TLabel").pack(anchor="w")
        ttk.Entry(box, textvariable=self.login_password, show="•").pack(fill="x", pady=(4, 15))
        line = ttk.Frame(box, style="Card.TFrame"); line.pack(fill="x")
        ttk.Button(line, text="Iniciar sesión", style="Primary.TButton", command=self.connect_and_login).pack(side="left")
        ttk.Button(line, text="Invitado", command=lambda: self.connect_and_login(True)).pack(side="left", padx=10)
        ttk.Button(box, text="¿Nuevo por aquí? Crear cuenta", command=self.registration_form).pack(anchor="center", pady=(16, 0))
        def update_role(*_):
            if self.login_role.get() == "administrador":
                self.code_login_row.pack_forget(); self.business_login_row.pack(fill="x", before=self.login_user_widget)
            else:
                self.business_login_row.pack_forget()
                if not self.saved_code(): self.code_login_row.pack(fill="x", before=self.login_user_widget)
                else: self.code_login_row.pack_forget()
        self.login_role.trace_add("write", update_role); update_role()
        ttk.Label(box, text="Aplicación nativa conectada a StockGo Cloud.", style="Card.TLabel", foreground=MUTED).pack(anchor="center", pady=(20, 0))
        ttk.Button(box, text="Recuperar contraseña", command=self.recovery_form).pack(anchor="center", pady=(8, 0))
    def connect(self):
        try:
            url, code = parse_sg1(self.sg_value.get()); self.api = Api(url, code)
            reply = self.api.call("POST", "connect", {"codigo": code}); self.remember(self.sg_value.get().strip()); self.login_screen(reply["nombreNegocio"])
        except ApiError as exc: messagebox.showerror("Conexión", str(exc), parent=self)
    def connect_and_login(self, guest=False):
        try:
            if self.login_role.get() == "administrador" and not guest:
                result = Api(DEFAULT_API).call("POST", "auth/admin-login", {"negocio": self.business_login.get().strip(), "usuario": self.login_user.get().strip(), "password": self.login_password.get()})
                self.sg_value.set(result["sg1"]); url, code = parse_sg1(result["sg1"]); self.api = Api(url, code)
                self.api.token, self.user = result["token"], result["usuario"]; self.remember(result["sg1"]); self.main_screen(result["nombreNegocio"])
            else:
                url, code = parse_sg1(self.sg_value.get()); self.api = Api(url, code)
                reply = self.api.call("POST", "connect", {"codigo": code}); self.remember(self.sg_value.get().strip())
                result = self.api.call("POST", "auth/guest" if guest else "auth/login", {} if guest else {"usuario": self.login_user.get().strip(), "password": self.login_password.get()})
                self.api.token, self.user = result["token"], result["usuario"]; self.main_screen(reply["nombreNegocio"])
        except ApiError as exc: messagebox.showerror("Acceso", str(exc), parent=self)
    def recovery_form(self):
        win = tk.Toplevel(self); win.title("Recuperar contraseña"); win.configure(bg=BG); win.transient(self); win.grab_set()
        box = self.card(win, 22); box.pack(fill="both", expand=True)
        ttk.Label(box, text="Solicitar recuperación", style="Title.TLabel").pack(anchor="w")
        ttk.Label(box, text="El administrador del negocio podrá generar una contraseña temporal.", style="Card.TLabel", wraplength=420).pack(anchor="w", pady=(5, 14))
        code, user = tk.StringVar(value=self.saved_code()), tk.StringVar()
        for label, value, secret in (("Código SG1", code, False), ("Usuario", user, False)):
            ttk.Label(box, text=label, style="Card.TLabel").pack(anchor="w", pady=(7, 1)); ttk.Entry(box, textvariable=value, show="•" if secret else "").pack(fill="x")
        def send():
            try:
                url, business = parse_sg1(code.get()); Api(url, business).call("POST", "auth/recovery-request", {"usuario": user.get().strip()})
                win.destroy(); messagebox.showinfo("Recuperación", "Solicitud enviada. Contacta al administrador del negocio.", parent=self)
            except ApiError as exc: messagebox.showerror("Recuperación", str(exc), parent=win)
        ttk.Button(box, text="Enviar solicitud", style="Primary.TButton", command=send).pack(anchor="e", pady=(18, 0))
    def registration_form(self):
        win = tk.Toplevel(self); win.title("Crear cuenta"); win.configure(bg=BG); win.transient(self); win.grab_set()
        box = self.card(win, 24); box.pack(fill="both", expand=True); owner = tk.BooleanVar(value=False); fields = {}
        ttk.Label(box, text="Empieza con StockGo", style="Title.TLabel").pack(anchor="w")
        hint = ttk.Label(box, text="Pega el código SG1 compartido por el administrador para crear tu cuenta de vendedor.", style="Card.TLabel", wraplength=440); hint.pack(anchor="w", pady=(5, 14))
        modes = ttk.Frame(box, style="Card.TFrame"); modes.pack(fill="x")
        ttk.Radiobutton(modes, text="Soy vendedor", variable=owner, value=False).pack(side="left")
        ttk.Radiobutton(modes, text="Crear mi negocio", variable=owner, value=True).pack(side="left", padx=16)
        owner_row = ttk.Frame(box, style="Card.TFrame"); vendor_row = ttk.Frame(box, style="Card.TFrame")
        for label, key, secret in (("Nombre único de la empresa", "negocio", False),):
            ttk.Label(owner_row, text=label, style="Card.TLabel").pack(anchor="w", pady=(10, 1)); fields[key] = ttk.Entry(owner_row); fields[key].pack(fill="x")
        ttk.Label(vendor_row, text="Código de negocio SG1", style="Card.TLabel").pack(anchor="w", pady=(10, 1)); fields["codigo"] = ttk.Entry(vendor_row); fields["codigo"].pack(fill="x")
        for label, key, secret in (("Nombres", "nombres", False), ("Apellidos", "apellidos", False), ("Usuario", "usuario", False), ("Contraseña", "password", True), ("Repite la contraseña", "confirm", True)):
            ttk.Label(box, text=label, style="Card.TLabel").pack(anchor="w", pady=(9, 1)); fields[key] = ttk.Entry(box, show="•" if secret else ""); fields[key].pack(fill="x")
        def draw(*_):
            if owner.get(): vendor_row.pack_forget(); owner_row.pack(fill="x"); hint.configure(text="Serás el administrador y recibirás el código SG1 para compartir con tus vendedores.")
            else: owner_row.pack_forget(); vendor_row.pack(fill="x"); hint.configure(text="Pega el código SG1 compartido por el administrador para crear tu cuenta de vendedor.")
        owner.trace_add("write", draw); draw()
        def create():
            try:
                if fields["password"].get() != fields["confirm"].get(): raise ApiError("Las contraseñas no coinciden.")
                body = {key: fields[key].get().strip() for key in ("nombres", "apellidos", "usuario", "password")}
                if owner.get():
                    body["negocio"] = fields["negocio"].get().strip(); reply = Api(DEFAULT_API).call("POST", "businesses", body)
                    self.sg_value.set(reply["sg1"]); win.destroy(); messagebox.showinfo("Negocio creado", "Guarda este código SG1 y compártelo con tus vendedores:\n\n" + reply["sg1"], parent=self); self.connect_screen()
                else:
                    url, code = parse_sg1(fields["codigo"].get()); Api(url, code).call("POST", "auth/register", body)
                    self.sg_value.set(fields["codigo"].get().strip()); win.destroy(); messagebox.showinfo("Cuenta creada", "Tu cuenta de vendedor ya puede iniciar sesión.", parent=self)
            except ApiError as exc: messagebox.showerror("Crear cuenta", str(exc), parent=win)
        ttk.Button(box, text="Crear cuenta", style="Primary.TButton", command=create).pack(anchor="e", pady=(18, 0))
    def login_screen(self, business):
        self.clear()
        root = ttk.Frame(self, padding=55); root.pack(fill="both", expand=True)
        box = self.card(root, 34); box.place(relx=.5, rely=.48, anchor="center", width=550)
        ttk.Label(box, text=business, style="Title.TLabel").pack(anchor="w")
        ttk.Label(box, text="Inicia sesión para operar el inventario.", style="Card.TLabel").pack(anchor="w", pady=(4, 20))
        username, password = tk.StringVar(), tk.StringVar()
        for label, var, secret in (("Usuario", username, False), ("Contraseña", password, True)):
            ttk.Label(box, text=label, style="Card.TLabel").pack(anchor="w", pady=(7, 2)); ttk.Entry(box, textvariable=var, show="•" if secret else "").pack(fill="x")
        def enter(guest=False):
            try:
                reply = self.api.call("POST", "auth/guest" if guest else "auth/login", {} if guest else {"usuario": username.get(), "password": password.get()})
                self.api.token, self.user = reply["token"], reply["usuario"]; self.main_screen(business)
            except ApiError as exc: messagebox.showerror("Acceso", str(exc), parent=self)
        buttons = ttk.Frame(box, style="Card.TFrame"); buttons.pack(fill="x", pady=(22, 0))
        ttk.Button(buttons, text="Ingresar", style="Primary.TButton", command=enter).pack(side="left")
        ttk.Button(buttons, text="Entrar como invitado", command=lambda: enter(True)).pack(side="left", padx=9)
        ttk.Button(box, text="Crear cuenta de vendedor", command=self.registration_form).pack(anchor="w", pady=(14, 0))
        ttk.Button(box, text="Cambiar negocio", command=self.connect_screen).pack(anchor="w", pady=(16, 0))
    def main_screen(self, business):
        self.clear(); self.cart = []
        root = ttk.Frame(self); root.pack(fill="both", expand=True)
        side = tk.Frame(root, bg=NAVY, width=220); side.pack(side="left", fill="y"); side.pack_propagate(False)
        tk.Label(side, text="StockGo", bg=NAVY, fg="white", font=("Segoe UI Semibold", 22)).pack(anchor="w", padx=22, pady=(28, 3))
        tk.Label(side, text=business, bg=NAVY, fg="#C9E9F4", wraplength=180, justify="left").pack(anchor="w", padx=22, pady=(0, 24))
        self.content = ttk.Frame(root, padding=30); self.content.pack(side="left", fill="both", expand=True)
        actions = [("Resumen", self.dashboard), ("Inventario", self.inventory)]
        if self.user.get("rol") in ("administrador", "vendedor"):
            actions.extend((("Nueva venta", self.sale), ("Mis ventas", self.sales)))
        if self.user.get("rol") == "administrador": actions.append(("Equipo", self.team))
        for title, command in actions: ttk.Button(side, text=title, style="Nav.TButton", command=command).pack(fill="x", padx=12, pady=3)
        tk.Label(side, text=f"{self.user.get('nombres', 'Invitado')}\n{self.user.get('rol', '')}", bg=NAVY, fg="#C9E9F4", justify="left").pack(side="bottom", anchor="w", padx=22, pady=13)
        ttk.Button(side, text="Cerrar sesión", command=self.logout).pack(side="bottom", fill="x", padx=12, pady=(0, 12))
        self.dashboard()
    def page(self, title, subtitle):
        for child in self.content.winfo_children(): child.destroy()
        ttk.Label(self.content, text=title, style="Title.TLabel").pack(anchor="w")
        ttk.Label(self.content, text=subtitle, foreground=MUTED).pack(anchor="w", pady=(3, 22))
    def error(self, message): ttk.Label(self.content, text=str(message), foreground=RED).pack(anchor="w", pady=20)
    def dashboard(self):
        self.page("Resumen", "Datos actuales del negocio en la nube.")
        try:
            products = self.api.call("GET", "products?limit=100")["productos"]
            sales = self.api.call("GET", "sales")["ventas"] if self.user.get("rol") != "invitado" else []
            total = sum(x["totalCentavos"] for x in sales if x["estado"] == "confirmada")
            cards = [("Productos activos", len(products), BLUE), ("Unidades en stock", sum(x["cantidad"] for x in products), "#138A72"), ("Ventas", len(sales), TEAL), ("Total vendido", money(total), "#D99A00")]
            row = ttk.Frame(self.content); row.pack(fill="x")
            for label, value, color in cards:
                card = tk.Frame(row, bg=WHITE, highlightbackground="#DCE8EF", highlightthickness=1, padx=18, pady=18); card.pack(side="left", fill="both", expand=True, padx=(0, 12))
                tk.Label(card, text=label, bg=WHITE, fg=MUTED).pack(anchor="w")
                tk.Label(card, text=str(value), bg=WHITE, fg=color, font=("Segoe UI Semibold", 20)).pack(anchor="w", pady=(8, 0))
            if self.user.get("rol") == "administrador":
                invite = self.card(self.content, 18); invite.pack(fill="x", pady=(20, 0))
                ttk.Label(invite, text="Código SG1 para vendedores", style="Card.TLabel", font=("Segoe UI Semibold", 14)).pack(anchor="w")
                ttk.Label(invite, text="Compártelo con tu equipo. Cada vendedor crea su propia cuenta; el código no da permisos de administrador.", style="Card.TLabel").pack(anchor="w", pady=(3, 8))
                code = "SG1-" + base64.urlsafe_b64encode(json.dumps({"url": self.api.url, "negocio": self.api.code}, separators=(",", ":")).encode()).decode().rstrip("=")
                value = tk.StringVar(value=code)
                field = ttk.Entry(invite, textvariable=value, font=("Consolas", 9)); field.pack(fill="x")
                ttk.Button(invite, text="Copiar código", command=lambda: (self.clipboard_clear(), self.clipboard_append(code), messagebox.showinfo("StockGo", "Código SG1 copiado.", parent=self))).pack(anchor="e", pady=(8, 0))
        except ApiError as exc: self.error(exc)
    def inventory(self):
        self.page("Inventario", "Consulta existencias y encuentra productos por nombre o código.")
        tools = ttk.Frame(self.content); tools.pack(fill="x", pady=(0, 12)); search = tk.StringVar()
        ttk.Entry(tools, textvariable=search, width=42).pack(side="left")
        tree = ttk.Treeview(self.content, columns=("sku", "category", "stock", "price"), show="tree headings")
        tree.heading("#0", text="Producto"); tree.column("#0", width=300)
        for key, title, width in (("sku", "Código", 150), ("category", "Categoría", 130), ("stock", "Stock", 80), ("price", "Precio venta", 120)):
            tree.heading(key, text=title); tree.column(key, width=width)
        tree.pack(fill="both", expand=True)
        def load():
            try:
                q = search.get().strip(); suffix = "&q=" + q.replace(" ", "%20") if q else ""
                self.products = self.api.call("GET", "products?limit=100" + suffix)["productos"]; tree.delete(*tree.get_children())
                for p in self.products: tree.insert("", "end", iid=str(p["id"]), text=p["nombre"], values=(p["codigo"], p["categoria"], p["cantidad"], f"Q {p['precio']:,.2f}"))
            except ApiError as exc: messagebox.showerror("Inventario", str(exc), parent=self)
        ttk.Button(tools, text="Buscar", style="Primary.TButton", command=load).pack(side="left", padx=8)
        if self.user.get("rol") == "administrador":
            ttk.Button(tools, text="Agregar producto", command=lambda: self.product_form(None, load)).pack(side="right")
            ttk.Button(tools, text="Editar seleccionado", command=lambda: self.edit_product(tree, load)).pack(side="right", padx=8)
            ttk.Button(tools, text="Desactivar / eliminar", command=lambda: self.deactivate_product(tree, load)).pack(side="right", padx=8)
        tree.bind("<Double-1>", lambda _: self.edit_product(tree, load) if self.user.get("rol") == "administrador" else None); load()
    def edit_product(self, tree, after):
        selected = tree.selection()
        if not selected: return messagebox.showinfo("Inventario", "Selecciona un producto.", parent=self)
        item = next((p for p in self.products if str(p["id"]) == selected[0]), None)
        if item: self.product_form(item, after)
    def deactivate_product(self, tree, after):
        selected = tree.selection()
        if not selected: return messagebox.showinfo("Inventario", "Selecciona un producto.", parent=self)
        item = next((p for p in self.products if str(p["id"]) == selected[0]), None)
        if not item: return
        answer = messagebox.askyesno("Desactivar producto", f"¿Desactivar {item['nombre']}?\n\nNo se borrará: se conservarán su ficha y el historial de ventas.", parent=self)
        if not answer: return
        try:
            self.api.call("POST", f"products/{item['id']}/deactivate", {})
            messagebox.showinfo("Inventario", "Producto desactivado. Ya no aparecerá para vender.", parent=self); after()
        except ApiError as exc: messagebox.showerror("Inventario", str(exc), parent=self)
    def product_form(self, item, after):
        win = tk.Toplevel(self); win.title("Editar producto" if item else "Agregar producto"); win.configure(bg=BG); win.transient(self); win.grab_set()
        box = self.card(win, 22); box.pack(fill="both", expand=True); data, old = {}, item or {}
        specs = [("Nombre", "nombre"), ("Código", "codigo"), ("Categoría", "categoria"), ("Cantidad", "cantidad"), ("Stock mínimo", "stockMinimo"), ("Precio de venta", "precio"), ("Costo de compra", "costo"), ("Marca", "marca"), ("Lote", "lote")]
        for label, key in specs:
            ttk.Label(box, text=label, style="Card.TLabel").pack(anchor="w", pady=(5, 1))
            default = str(old.get(key, "Repuesto" if key == "categoria" else "0" if key in ("cantidad", "stockMinimo", "precio", "costo") else "")); value = tk.StringVar(value=default)
            field = ttk.Combobox(box, textvariable=value, values=("Repuesto", "Lubricante", "Filtro", "Aditivo", "Accesorio"), state="readonly") if key == "categoria" else ttk.Entry(box, textvariable=value, width=46)
            field.pack(fill="x"); data[key] = value
        photo = {"changed": False, "value": None}
        photo_status = tk.StringVar(value="Imagen actual disponible" if old.get("imagen") else "Sin imagen")
        ttk.Label(box, text="Imagen del producto", style="Card.TLabel").pack(anchor="w", pady=(12, 1))
        ttk.Label(box, textvariable=photo_status, style="Card.TLabel", foreground=MUTED).pack(anchor="w")
        photo_actions = ttk.Frame(box, style="Card.TFrame"); photo_actions.pack(fill="x", pady=(5, 3))
        def choose_photo():
            path = filedialog.askopenfilename(parent=win, title="Elegir imagen", filetypes=[("Imágenes", "*.jpg *.jpeg *.png *.webp"), ("Todos los archivos", "*.*")])
            if not path: return
            try:
                photo["value"], size = webp_image(path); photo["changed"] = True
                photo_status.set(f"WebP optimizada: {size / 1024:.1f} KB (máximo 10 KB)")
            except ApiError as exc: messagebox.showerror("Imagen", str(exc), parent=win)
        def remove_photo():
            photo["changed"], photo["value"] = True, None; photo_status.set("La imagen se quitará al guardar")
        ttk.Button(photo_actions, text="Elegir imagen", command=choose_photo).pack(side="left")
        ttk.Button(photo_actions, text="Quitar imagen", command=remove_photo).pack(side="left", padx=8)
        def save():
            try:
                body = {key: data[key].get().strip() for _, key in specs}
                body["cantidad"], body["stockMinimo"] = int(body["cantidad"]), int(body["stockMinimo"])
                body["precio"], body["costo"] = float(body["precio"]), float(body["costo"])
                if photo["changed"]: body["imagen"] = photo["value"]
                self.api.call("PUT" if item else "POST", f"products/{item['id']}" if item else "products", body); win.destroy(); after()
            except (ValueError, ApiError) as exc: messagebox.showerror("Producto", str(exc), parent=win)
        ttk.Button(box, text="Guardar producto", style="Primary.TButton", command=save).pack(anchor="e", pady=(15, 0))
    def sale(self):
        self.page("Nueva venta", "Agrega varios productos al carrito y registra el cliente de esta venta.")
        if self.user.get("rol") == "invitado": return self.error("El acceso de invitado no puede registrar ventas.")
        try: products = self.api.call("GET", "products?limit=100")["productos"]
        except ApiError as exc: return self.error(exc)
        left = ttk.Frame(self.content); left.pack(side="left", fill="both", expand=True, padx=(0, 16)); right = self.card(self.content, 18); right.pack(side="right", fill="both", expand=True)
        select = ttk.Treeview(left, columns=("stock", "price"), show="tree headings"); select.heading("#0", text="Producto"); select.heading("stock", text="Stock"); select.heading("price", text="Precio"); select.column("#0", width=300); select.pack(fill="both", expand=True)
        for product in products: select.insert("", "end", iid=str(product["id"]), text=product["nombre"], values=(product["cantidad"], f"Q {product['precio']:,.2f}"))
        cart = ttk.Treeview(right, columns=("qty", "total"), show="tree headings", height=10); cart.heading("#0", text="Carrito"); cart.heading("qty", text="Cant."); cart.heading("total", text="Subtotal"); cart.pack(fill="both", expand=True)
        total = ttk.Label(right, text="Total: Q 0.00", style="Card.TLabel", font=("Segoe UI Semibold", 15)); total.pack(anchor="e", pady=10)
        def draw():
            cart.delete(*cart.get_children()); amount = 0
            for row in self.cart:
                subtotal = round(row["precio"] * 100) * row["cantidad"]; amount += subtotal
                cart.insert("", "end", iid=str(row["id"]), text=row["nombre"], values=(row["cantidad"], money(subtotal)))
            total.configure(text="Total: " + money(amount))
        def add():
            chosen = select.selection()
            if not chosen: return
            product = next(x for x in products if str(x["id"]) == chosen[0])
            qty = simpledialog.askinteger("Cantidad", f"{product['nombre']}\nDisponible: {product['cantidad']}", minvalue=1, maxvalue=product["cantidad"], parent=self)
            if not qty: return
            current = next((x for x in self.cart if x["id"] == product["id"]), None)
            if current: current["cantidad"] += qty
            else: self.cart.append({"id": product["id"], "nombre": product["nombre"], "cantidad": qty, "precio": product["precio"]})
            draw()
        ttk.Button(left, text="Agregar al carrito", style="Primary.TButton", command=add).pack(anchor="e", pady=10)
        def remove():
            chosen = set(cart.selection()); self.cart[:] = [x for x in self.cart if str(x["id"]) not in chosen]; draw()
        ttk.Button(right, text="Quitar seleccionado", command=remove).pack(anchor="e")
        ttk.Label(right, text="Cliente / descripción", style="Card.TLabel").pack(anchor="w", pady=(15, 2)); client = ttk.Entry(right); client.pack(fill="x")
        ttk.Label(right, text="Datos adicionales (opcional)", style="Card.TLabel").pack(anchor="w", pady=(8, 2)); description = tk.Text(right, height=4, wrap="word"); description.pack(fill="x")
        def confirm():
            if not self.cart: return messagebox.showwarning("Venta", "Agrega al menos un producto.", parent=self)
            try:
                body = {"solicitud": secrets.token_urlsafe(20), "cliente": {"nombre": client.get().strip(), "descripcion": description.get("1.0", "end").strip()}, "lineas": [{"productoId": x["id"], "cantidad": x["cantidad"], "precioEsperadoCentavos": round(x["precio"] * 100)} for x in self.cart]}
                sold = self.api.call("POST", "sales", body)["venta"]
                messagebox.showinfo("Venta confirmada", f"Venta #{sold['id']} registrada por {sold['vendedor']}.\nTotal: {money(sold['totalCentavos'])}", parent=self)
                self.cart.clear(); self.sale()
            except ApiError as exc: messagebox.showerror("Venta", str(exc), parent=self)
        ttk.Button(right, text="Confirmar venta", style="Primary.TButton", command=confirm).pack(fill="x", pady=16)
    def sales(self):
        self.page("Ventas", "Historial y seguimiento de las ventas registradas.")
        if self.user.get("rol") == "invitado": return self.error("El acceso de invitado no puede consultar ventas.")
        tree = ttk.Treeview(self.content, columns=("seller", "client", "total", "state"), show="tree headings"); tree.heading("#0", text="# / Fecha"); tree.column("#0", width=220)
        for key, label, width in (("seller", "Vendedor", 180), ("client", "Cliente", 220), ("total", "Total", 110), ("state", "Estado", 110)): tree.heading(key, text=label); tree.column(key, width=width)
        tree.pack(fill="both", expand=True)
        try:
            for sale in self.api.call("GET", "sales")["ventas"]:
                tree.insert("", "end", iid=str(sale["id"]), text=f"#{sale['id']} · {sale['fecha'][:16].replace('T', ' ')}", values=(sale["vendedor"], sale["cliente"]["nombre"], money(sale["totalCentavos"]), sale["estado"]))
        except ApiError as exc: return self.error(exc)
        if self.user.get("rol") == "administrador":
            def cancel():
                selected = tree.selection()
                if not selected: return
                reason = simpledialog.askstring("Anular venta", "Motivo de la anulación:", parent=self)
                if not reason: return
                try: self.api.call("POST", f"sales/{selected[0]}/cancel", {"motivo": reason}); self.sales()
                except ApiError as exc: messagebox.showerror("Anular venta", str(exc), parent=self)
            ttk.Button(self.content, text="Anular venta seleccionada", command=cancel).pack(anchor="e", pady=12)
    def team(self):
        self.page("Equipo", "Usuarios que pertenecen a este negocio.")
        tree = ttk.Treeview(self.content, columns=("role", "internal"), show="tree headings"); tree.heading("#0", text="Nombre"); tree.heading("role", text="Rol"); tree.heading("internal", text="Código interno"); tree.pack(fill="both", expand=True)
        def load():
            try:
                tree.delete(*tree.get_children())
                for person in self.api.call("GET", "users")["usuarios"]:
                    tree.insert("", "end", iid=str(person["id"]), text=(person["nombres"] + " " + person["apellidos"]).strip(), values=(person["rol"], person["codigoInterno"]))
            except ApiError as exc: messagebox.showerror("Equipo", str(exc), parent=self)
        def add():
            win = tk.Toplevel(self); win.title("Agregar miembro"); win.configure(bg=BG); win.transient(self); win.grab_set()
            box = self.card(win, 20); box.pack(fill="both", expand=True); fields = {}
            for label, key in (("Usuario", "usuario"), ("Nombres", "nombres"), ("Apellidos", "apellidos"), ("Contraseña", "password"), ("Rol (vendedor o administrador)", "rol")):
                ttk.Label(box, text=label, style="Card.TLabel").pack(anchor="w", pady=(6, 1))
                field = ttk.Entry(box, show="•" if key == "password" else ""); field.pack(fill="x"); fields[key] = field
            fields["rol"].insert(0, "vendedor")
            def save():
                try: self.api.call("POST", "users", {key: field.get().strip() for key, field in fields.items()}); win.destroy(); load()
                except ApiError as exc: messagebox.showerror("Equipo", str(exc), parent=win)
            ttk.Button(box, text="Agregar", style="Primary.TButton", command=save).pack(anchor="e", pady=14)
        ttk.Button(self.content, text="Agregar vendedor", style="Primary.TButton", command=add).pack(anchor="e", pady=12)
        load()
    def logout(self):
        try: self.api.call("POST", "auth/logout", {})
        except ApiError: pass
        self.api.token = ""; self.user = {}; self.connect_screen()
