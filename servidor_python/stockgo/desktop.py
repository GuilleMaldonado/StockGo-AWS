"""Panel gráfico del maestro: negocio, contraseña de administrador y código SG1."""
import ipaddress
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from .database import Catalog, Error, config, connection, matches, sg1
from .http_server import Server, addresses


class Desktop:
    def __init__(self, catalog_root=None, server_factory=Server):
        self.catalog = Catalog(catalog_root)
        self.server_factory = server_factory
        self.server = None
        self.root = tk.Tk()
        self.root.title('StockGo · Servidor Python')
        self.root.geometry('850x760')
        self.root.minsize(680, 680)
        self.root.configure(bg='#edf6fc')
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TFrame', background='#edf6fc')
        style.configure('TLabel', background='#edf6fc', foreground='#123b56', font=('Segoe UI', 11))
        style.configure('Title.TLabel', font=('Segoe UI', 26, 'bold'), foreground='#0073b1')
        style.configure('TButton', font=('Segoe UI', 11, 'bold'), padding=10)
        style.configure('TEntry', padding=8)
        canvas = tk.Canvas(self.root, bg='#edf6fc', highlightthickness=0)
        scrollbar = ttk.Scrollbar(self.root, orient='vertical', command=canvas.yview)
        canvas.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        canvas.pack(side='left', fill='both', expand=True)
        frame = ttk.Frame(canvas, padding=28)
        window_id = canvas.create_window((0, 0), window=frame, anchor='nw')
        frame.bind('<Configure>', lambda _: canvas.configure(scrollregion=canvas.bbox('all')))
        canvas.bind('<Configure>', lambda e: canvas.itemconfigure(window_id, width=e.width))
        canvas.bind_all('<MouseWheel>', lambda e: canvas.yview_scroll(-int(e.delta / 120), 'units'))
        ttk.Label(frame, text='StockGo', style='Title.TLabel').pack(anchor='w')
        ttk.Label(frame, text='Tu negocio, conectado. Android Kotlin · iOS · Web · Escritorio').pack(anchor='w', pady=(0, 20))
        ttk.Label(frame, text='1. Selecciona o crea tu negocio').pack(anchor='w')
        self.business = ttk.Combobox(frame, state='readonly')
        self.business.pack(fill='x', pady=8)
        self.business.bind('<<ComboboxSelected>>', lambda _: self.clear_code())
        actions = ttk.Frame(frame)
        actions.pack(fill='x')
        self.create_btn = ttk.Button(actions, text='+ Crear negocio', command=self.create)
        self.create_btn.pack(side='left')
        self.import_btn = ttk.Button(actions, text='Importar negocio Flutter', command=self.import_business)
        self.import_btn.pack(side='left', padx=8)
        ttk.Label(frame, text='2. Confirma tu cuenta Administrador').pack(anchor='w', pady=(20, 5))
        self.user = ttk.Entry(frame)
        self.user.pack(fill='x', pady=4)
        ttk.Label(frame, text='Contraseña del administrador del negocio seleccionado').pack(anchor='w')
        self.password = ttk.Entry(frame, show='●')
        self.password.pack(fill='x', pady=6)
        self.start_btn = ttk.Button(frame, text='Iniciar servidor', command=self.toggle)
        self.start_btn.pack(fill='x', pady=8)
        self.status = ttk.Label(frame, text='Servidor detenido')
        self.status.pack(anchor='w', pady=5)
        ttk.Label(frame, text='3. Selecciona la dirección que alcanza el otro dispositivo').pack(anchor='w', pady=(15, 5))
        self.address = ttk.Combobox(frame, state='readonly')
        self.address.pack(fill='x')
        self.address.bind('<<ComboboxSelected>>', lambda _: self.show_code())
        self.code = tk.Text(frame, height=5, wrap='char', bg='white', fg='#0073b1', relief='flat', font=('Consolas', 11), padx=12, pady=12)
        self.code.pack(fill='x', pady=8)
        self.code.configure(state='disabled')
        self.copy_btn = ttk.Button(frame, text='Copiar código para el equipo', command=self.copy, state='disabled')
        self.copy_btn.pack(fill='x')
        ttk.Label(frame, text='En Android: pega el código → Conectar → Iniciar sesión.\n'
                  'En Flutter: Conectarme a un negocio → pegar código.\n'
                  'Wi-Fi: usa la IP de esta PC. Emulador Android: 10.0.2.2.\n'
                  'Mantén este panel abierto. Cerrar el panel detiene el servidor.', wraplength=740).pack(anchor='w', pady=15)
        self.root.protocol('WM_DELETE_WINDOW', self.close)
        self.refresh()

    def refresh(self):
        self.businesses = self.catalog.list()
        self.business['values'] = [b['nombre'] for b in self.businesses]
        if self.businesses:
            self.business.current(len(self.businesses) - 1)

    def clear_code(self):
        self.code.configure(state='normal')
        self.code.delete('1.0', 'end')
        self.code.configure(state='disabled')

    def show_code(self):
        self.clear_code()
        if not self.server or not self.address.get():
            return
        host = self.address.get().split('//')[1].split(':')[0]
        vpn = ipaddress.ip_address(host) in ipaddress.ip_network('100.64.0.0/10')
        value = sg1(self.address.get(), self.server.service.code, vpn)
        self.code.configure(state='normal')
        self.code.insert('1.0', value)
        self.code.configure(state='disabled')

    def copy(self):
        value = self.code.get('1.0', 'end').strip()
        if value:
            self.root.clipboard_clear()
            self.root.clipboard_append(value)
            self.status.configure(text='Código copiado. Compártelo solo con el equipo autorizado.')

    def create(self):
        window = tk.Toplevel(self.root)
        window.title('Crear negocio y administrador')
        window.transient(self.root)
        window.grab_set()
        form = ttk.Frame(window, padding=25)
        form.pack(fill='both', expand=True)
        fields = {}
        for key, label in [('negocio', 'Nombre del negocio (único en esta PC)'), ('usuario', 'Usuario administrador (sin números)'),
                           ('nombres', 'Nombres'), ('apellidos', 'Apellidos'), ('password', 'Contraseña (8–128 caracteres)'),
                           ('confirmacion', 'Repite la contraseña')]:
            ttk.Label(form, text=label).pack(anchor='w')
            entry = ttk.Entry(form, width=48, show='●' if key in ('password', 'confirmacion') else '')
            entry.pack(fill='x', pady=(3, 9))
            fields[key] = entry

        def save():
            values = {k: f.get() for k, f in fields.items()}
            try:
                if values['password'] != values['confirmacion']:
                    raise Error('Las contraseñas no coinciden.')
                self.catalog.create(values.pop('negocio'), values)
                self.refresh()
                window.destroy()
                self.status.configure(text='Negocio creado. Inicia el servidor con tu cuenta Administrador.')
            except (Error, OSError) as exc:
                messagebox.showerror('Revisa los datos', str(exc), parent=window)
        ttk.Button(form, text='Crear negocio', command=save).pack(fill='x')

    def import_business(self):
        source = filedialog.askopenfilename(title='Selecciona la base de un negocio Flutter (esquema 10)',
                                           filetypes=[('Base SQLite', '*.db *.sqlite *.sqlite3'), ('Todos', '*.*')])
        if not source:
            return
        try:
            self.catalog.import_database(source)
            self.refresh()
            self.status.configure(text='Copia importada. El archivo original permanece intacto; usa tus credenciales actuales.')
        except Exception as exc:
            messagebox.showerror('No se pudo importar', str(exc))

    def toggle(self):
        if self.server:
            self.server.stop()
            self.server = None
            self.start_btn.configure(text='Iniciar servidor')
            self.business.configure(state='readonly')
            self.create_btn.configure(state='normal')
            self.import_btn.configure(state='normal')
            self.copy_btn.configure(state='disabled')
            self.address.set('')
            self.clear_code()
            self.status.configure(text='Servidor detenido. Las sesiones fueron cerradas.')
            return
        if self.business.current() < 0:
            messagebox.showinfo('Negocio', 'Primero crea o importa un negocio.')
            return
        business = self.businesses[self.business.current()]
        db = connection(business['ruta'])
        try:
            row = db.execute('SELECT * FROM usuarios WHERE nombre=?', (self.user.get().strip().lower(),)).fetchone()
            if not row or not matches(self.password.get(), row) or row['rol'] != 'administrador' or row['requiereCambioPassword']:
                raise Error('Usa una cuenta Administrador vigente de este negocio. Si tiene contraseña temporal, cámbiala desde un cliente conectado antes de reiniciar el servidor.')
            self.server = self.server_factory(business['ruta'])
            self.server.start()
            choices = addresses(self.server.port)
            choices.append(f'http://10.0.2.2:{self.server.port}')
            self.address['values'] = choices
            self.address.current(0)
            self.show_code()
            self.start_btn.configure(text='Detener servidor')
            self.business.configure(state='disabled')
            self.create_btn.configure(state='disabled')
            self.import_btn.configure(state='disabled')
            self.copy_btn.configure(state='normal')
            self.status.configure(text=f"Servidor activo · {business['nombre']} · Puerto {self.server.port}")
        except (Error, OSError) as exc:
            messagebox.showerror('No se pudo iniciar', str(exc))
        finally:
            db.close()
            self.password.delete(0, 'end')

    def close(self):
        if self.server:
            self.server.stop()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


def main():
    Desktop().run()
