"""Lanzador Python para la interfaz web central, sin base de datos en la PC."""
import tkinter as tk
from tkinter import messagebox, ttk
from urllib.parse import urlsplit
import webbrowser


def main():
    root = tk.Tk()
    root.title('StockGo Cloud')
    root.geometry('580x350')
    root.configure(bg='#f2f8fc')
    style = ttk.Style(); style.theme_use('clam')
    style.configure('TFrame', background='#f2f8fc')
    style.configure('TLabel', background='#f2f8fc', foreground='#123b56', font=('Segoe UI', 11))
    style.configure('Title.TLabel', font=('Segoe UI', 27, 'bold'), foreground='#0073b1')
    style.configure('TButton', font=('Segoe UI', 11, 'bold'), padding=12)
    frame = ttk.Frame(root, padding=30); frame.pack(fill='both', expand=True)
    ttk.Label(frame, text='StockGo Cloud', style='Title.TLabel').pack(anchor='w')
    ttk.Label(frame, text='Inventario y ventas conectados a la nube central.').pack(anchor='w', pady=12)
    ttk.Label(frame, text='Dirección HTTPS del sitio web StockGo publicado').pack(anchor='w')
    entry = ttk.Entry(frame, font=('Segoe UI', 12)); entry.insert(0, 'https://app.tu-dominio.example')
    entry.pack(fill='x', pady=15)
    def open_app():
        url = entry.get().strip().rstrip('/')
        parsed = urlsplit(url)
        if parsed.username or parsed.password or parsed.query or parsed.fragment or not parsed.hostname or parsed.scheme != 'https':
            messagebox.showerror('Dirección inválida', 'Usa la dirección HTTPS del sitio web publicado.')
            return
        webbrowser.open(url)
    ttk.Button(frame, text='Abrir StockGo', command=open_app).pack(fill='x')
    ttk.Label(frame, text='Entra con el código de tu negocio y tu cuenta.\nEsta PC no alojará la base de datos ni el servidor.').pack(anchor='w', pady=18)
    root.mainloop()


if __name__ == '__main__': main()
