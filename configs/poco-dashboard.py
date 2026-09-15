#!/usr/bin/env python3
# ==============================================================================
# POCO F4 (munch) - System Performance & Monitoring Dashboard
# Built with Python 3 + GTK4 / Libadwaita for AMOLED Vertical Portrait (1080x2400)
# ==============================================================================

import os
import sys
import glob
import time
import socket
import subprocess
import psutil

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Pango, Gdk

CSS_DATA = b"""
window {
    background-color: #000000;
    color: #ffffff;
}

.dashboard-container {
    padding: 16px;
    background-color: #000000;
}

.header-card {
    background: linear-gradient(135deg, #181d26, #101216);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 18px;
    padding: 18px;
    margin-bottom: 12px;
}

.metric-card {
    background-color: #121417;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 18px;
    padding: 16px;
    margin-bottom: 12px;
}

.card-title {
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    color: #9cb0c3;
}

.big-value {
    font-size: 32px;
    font-weight: 800;
    color: #ffffff;
    margin: 4px 0;
}

.sub-value {
    font-size: 13px;
    font-weight: 500;
    color: #a0a6b2;
}

.badge-tag {
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 8px;
}

.badge-green {
    background-color: rgba(46, 194, 126, 0.2);
    color: #2ec27e;
    border: 1px solid rgba(46, 194, 126, 0.35);
}

.badge-blue {
    background-color: rgba(53, 132, 228, 0.2);
    color: #3584e4;
    border: 1px solid rgba(53, 132, 228, 0.35);
}

.badge-orange {
    background-color: rgba(255, 120, 0, 0.2);
    color: #ff7800;
    border: 1px solid rgba(255, 120, 0, 0.35);
}

.badge-purple {
    background-color: rgba(145, 65, 172, 0.2);
    color: #c061cb;
    border: 1px solid rgba(145, 65, 172, 0.35);
}

.action-btn {
    border-radius: 14px;
    font-weight: 700;
    font-size: 14px;
    padding: 14px;
    margin: 4px;
    background-color: #1a1e27;
    color: #ffffff;
    border: 1px solid rgba(255, 255, 255, 0.12);
}

.action-btn:hover {
    background-color: #262c38;
}

.action-btn:active {
    background-color: #3584e4;
}

progressbar trough {
    min-height: 8px;
    border-radius: 6px;
    background-color: rgba(255, 255, 255, 0.08);
}

.progress-bat progress {
    background: linear-gradient(90deg, #26a269, #2ec27e);
    border-radius: 6px;
}

.progress-cpu progress {
    background: linear-gradient(90deg, #1c71d8, #3584e4);
    border-radius: 6px;
}

.progress-mem progress {
    background: linear-gradient(90deg, #782b99, #9141ac);
    border-radius: 6px;
}

.progress-disk progress {
    background: linear-gradient(90deg, #e66100, #ff7800);
    border-radius: 6px;
}
"""

def read_sysfs(path, default=""):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        return default

def make_header_row(icon_name, title_text, badge_text, badge_css):
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    if icon_name:
        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(18)
        row.append(img)
    lbl = Gtk.Label(label=title_text)
    lbl.set_css_classes(["card-title"])
    row.append(lbl)

    badge = Gtk.Label(label=badge_text)
    badge.set_halign(Gtk.Align.END)
    badge.set_hexpand(True)
    badge.set_css_classes(["badge-tag", badge_css])
    row.append(badge)
    return row, badge

def make_action_btn(icon_name, label_text, callback):
    btn = Gtk.Button()
    btn.add_css_class("action-btn")
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    box.set_halign(Gtk.Align.CENTER)
    if icon_name:
        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(20)
        box.append(img)
    lbl = Gtk.Label(label=label_text)
    box.append(lbl)
    btn.set_child(box)
    btn.connect("clicked", lambda b: callback())
    return btn

class PocoDashboardWindow(Adw.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.set_title("POCO F4 Panel de Sistema")
        self.set_default_size(540, 1100)

        # Scrolled container for portrait touch screen
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.add_css_class("dashboard-container")
        scrolled.set_child(main_box)
        self.set_content(scrolled)

        # 1. HEADER CARD
        header_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        header_card.add_css_class("header-card")

        title_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        img_phone = Gtk.Image.new_from_icon_name("phone-symbolic")
        img_phone.set_pixel_size(24)
        title_row.append(img_phone)

        lbl_device = Gtk.Label(label="POCO F4 5G")
        lbl_device.set_halign(Gtk.Align.START)
        lbl_device.set_css_classes(["big-value"])
        title_row.append(lbl_device)

        lbl_soc = Gtk.Label(label="Snapdragon 870")
        lbl_soc.set_halign(Gtk.Align.END)
        lbl_soc.set_hexpand(True)
        lbl_soc.set_css_classes(["badge-tag", "badge-blue"])
        title_row.append(lbl_soc)
        header_card.append(title_row)

        self.lbl_net = Gtk.Label(label="Red: Detectando...")
        self.lbl_net.set_halign(Gtk.Align.START)
        self.lbl_net.set_css_classes(["sub-value"])
        header_card.append(self.lbl_net)

        self.lbl_uptime = Gtk.Label(label="Actividad: ...")
        self.lbl_uptime.set_halign(Gtk.Align.START)
        self.lbl_uptime.set_css_classes(["sub-value"])
        header_card.append(self.lbl_uptime)

        main_box.append(header_card)

        # 2. BATTERY CARD
        self.card_bat = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.card_bat.add_css_class("metric-card")
        
        bat_header, self.badge_bat_status = make_header_row("battery-symbolic", "BATERÍA", "Normal", "badge-green")
        self.card_bat.append(bat_header)

        self.lbl_bat_val = Gtk.Label(label="--%")
        self.lbl_bat_val.set_halign(Gtk.Align.START)
        self.lbl_bat_val.set_css_classes(["big-value"])
        self.card_bat.append(self.lbl_bat_val)

        self.prog_bat = Gtk.ProgressBar()
        self.prog_bat.set_css_classes(["progress-bat"])
        self.prog_bat.set_fraction(1.0)
        self.card_bat.append(self.prog_bat)

        self.lbl_bat_sub = Gtk.Label(label="Tensión: -- V  |  Temperatura: -- °C")
        self.lbl_bat_sub.set_halign(Gtk.Align.START)
        self.lbl_bat_sub.set_css_classes(["sub-value"])
        self.card_bat.append(self.lbl_bat_sub)
        main_box.append(self.card_bat)

        # 3. CPU CARD
        card_cpu = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card_cpu.add_css_class("metric-card")

        cpu_header, badge_cpu = make_header_row("computer-symbolic", "PROCESADOR (CPU)", "8 Núcleos Kryo", "badge-blue")
        card_cpu.append(cpu_header)

        self.lbl_cpu_val = Gtk.Label(label="--%")
        self.lbl_cpu_val.set_halign(Gtk.Align.START)
        self.lbl_cpu_val.set_css_classes(["big-value"])
        card_cpu.append(self.lbl_cpu_val)

        self.prog_cpu = Gtk.ProgressBar()
        self.prog_cpu.set_css_classes(["progress-cpu"])
        self.prog_cpu.set_fraction(0.0)
        card_cpu.append(self.prog_cpu)

        self.lbl_cpu_sub = Gtk.Label(label="Carga media: --, --, --")
        self.lbl_cpu_sub.set_halign(Gtk.Align.START)
        self.lbl_cpu_sub.set_css_classes(["sub-value"])
        card_cpu.append(self.lbl_cpu_sub)
        main_box.append(card_cpu)

        # 4. RAM CARD
        card_mem = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card_mem.add_css_class("metric-card")

        mem_header, badge_mem = make_header_row("media-flash-symbolic", "MEMORIA RAM", "LPDDR5", "badge-purple")
        card_mem.append(mem_header)

        self.lbl_mem_val = Gtk.Label(label="-- GB / -- GB")
        self.lbl_mem_val.set_halign(Gtk.Align.START)
        self.lbl_mem_val.set_css_classes(["big-value"])
        card_mem.append(self.lbl_mem_val)

        self.prog_mem = Gtk.ProgressBar()
        self.prog_mem.set_css_classes(["progress-mem"])
        self.prog_mem.set_fraction(0.0)
        card_mem.append(self.prog_mem)

        self.lbl_mem_sub = Gtk.Label(label="Disponible: -- GB (--% usado)")
        self.lbl_mem_sub.set_halign(Gtk.Align.START)
        self.lbl_mem_sub.set_css_classes(["sub-value"])
        card_mem.append(self.lbl_mem_sub)
        main_box.append(card_mem)

        # 5. DISK CARD (CAPACITY)
        card_disk = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card_disk.add_css_class("metric-card")

        disk_header, badge_disk = make_header_row("drive-harddisk-solidstate-symbolic", "ALMACENAMIENTO (DISCO)", "UFS 3.1", "badge-orange")
        card_disk.append(disk_header)

        self.lbl_disk_val = Gtk.Label(label="-- GB / -- GB")
        self.lbl_disk_val.set_halign(Gtk.Align.START)
        self.lbl_disk_val.set_css_classes(["big-value"])
        card_disk.append(self.lbl_disk_val)

        self.prog_disk = Gtk.ProgressBar()
        self.prog_disk.set_css_classes(["progress-disk"])
        self.prog_disk.set_fraction(0.0)
        card_disk.append(self.prog_disk)

        self.lbl_disk_sub = Gtk.Label(label="Capacidad Total: 104 GB  |  Libre: -- GB")
        self.lbl_disk_sub.set_halign(Gtk.Align.START)
        self.lbl_disk_sub.set_css_classes(["sub-value"])
        card_disk.append(self.lbl_disk_sub)
        main_box.append(card_disk)

        # 6. QUICK ACTIONS CARD
        card_actions = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card_actions.add_css_class("metric-card")

        lbl_actions_title = Gtk.Label(label="ACCIONES RÁPIDAS")
        lbl_actions_title.set_halign(Gtk.Align.START)
        lbl_actions_title.set_css_classes(["card-title"])
        card_actions.append(lbl_actions_title)

        grid_actions = Gtk.Grid()
        grid_actions.set_column_homogeneous(True)
        grid_actions.set_row_homogeneous(True)
        grid_actions.set_column_spacing(8)
        grid_actions.set_row_spacing(8)

        btn_term = make_action_btn("utilities-terminal-symbolic", "Terminal", lambda: subprocess.Popen(["xfce4-terminal"]))
        grid_actions.attach(btn_term, 0, 0, 1, 1)

        btn_files = make_action_btn("system-file-manager-symbolic", "Archivos", lambda: subprocess.Popen(["thunar"]))
        grid_actions.attach(btn_files, 1, 0, 1, 1)

        btn_sleep = make_action_btn("weather-clear-night-symbolic", "Apagar Pantalla", lambda: subprocess.Popen(["/usr/local/bin/poco-screen", "off"]))
        grid_actions.attach(btn_sleep, 0, 1, 1, 1)

        btn_reboot = make_action_btn("system-reboot-symbolic", "Reiniciar", lambda: subprocess.Popen(["reboot"]))
        grid_actions.attach(btn_reboot, 1, 1, 1, 1)

        card_actions.append(grid_actions)
        main_box.append(card_actions)

        # Initial data update and register timer
        self.update_stats()
        GLib.timeout_add_seconds(2, self.update_stats)

    def update_stats(self):
        try:
            # 1. Network & Uptime
            ips = []
            for iface, addrs in psutil.net_if_addrs().items():
                for addr in addrs:
                    if addr.family == socket.AF_INET and not iface.startswith("lo"):
                        ips.append(f"{iface}: {addr.address}")
            ip_str = " | ".join(ips) if ips else "Sin conexión"
            self.lbl_net.set_label(f"Red: {ip_str}")

            uptime_sec = int(time.time() - psutil.boot_time())
            hours, remainder = divmod(uptime_sec, 3600)
            minutes, _ = divmod(remainder, 60)
            self.lbl_uptime.set_label(f"Actividad: {hours}h {minutes}m")

            # 2. Battery
            bat_dir = "/sys/class/power_supply/qcom-battery"
            if not os.path.exists(bat_dir):
                bat_dir = "/sys/class/power_supply/battery"
            if not os.path.exists(bat_dir):
                for d in glob.glob("/sys/class/power_supply/*"):
                    if os.path.exists(os.path.join(d, "capacity")):
                        bat_dir = d
                        break

            cap = read_sysfs(f"{bat_dir}/capacity", "100")
            status = read_sysfs(f"{bat_dir}/status", "Batería")
            temp = read_sysfs(f"{bat_dir}/temp", "0")
            volt = read_sysfs(f"{bat_dir}/voltage_now", "0")
            try:
                temp_c = float(temp) / 10.0
                volt_v = float(volt) / 1000000.0
                cap_int = int(cap)
            except Exception:
                temp_c, volt_v, cap_int = 0.0, 0.0, 100

            self.lbl_bat_val.set_label(f"{cap_int}%")
            self.prog_bat.set_fraction(max(0.0, min(1.0, cap_int / 100.0)))
            self.lbl_bat_sub.set_label(f"Tensión: {volt_v:.2f} V  |  Temperatura: {temp_c:.1f} °C")
            
            # Badge status translation
            st_text = "Descargando"
            if "charg" in status.lower():
                st_text = "Cargando"
            elif "full" in status.lower():
                st_text = "Completa"
            self.badge_bat_status.set_label(st_text)

            # 3. CPU
            cpu_pct = psutil.cpu_percent(interval=None)
            load1, load5, load15 = psutil.getloadavg()
            self.lbl_cpu_val.set_label(f"{cpu_pct:.1f}%")
            self.prog_cpu.set_fraction(max(0.0, min(1.0, cpu_pct / 100.0)))
            self.lbl_cpu_sub.set_label(f"Carga media: {load1:.2f}, {load5:.2f}, {load15:.2f}")

            # 4. RAM
            mem = psutil.virtual_memory()
            mem_used_gb = mem.used / (1024**3)
            mem_total_gb = mem.total / (1024**3)
            mem_avail_gb = mem.available / (1024**3)
            self.lbl_mem_val.set_label(f"{mem_used_gb:.2f} GB / {mem_total_gb:.2f} GB")
            self.prog_mem.set_fraction(max(0.0, min(1.0, mem.percent / 100.0)))
            self.lbl_mem_sub.set_label(f"Libre: {mem_avail_gb:.2f} GB ({mem.percent:.1f}% en uso)")

            # 5. DISK
            disk = psutil.disk_usage("/")
            disk_used_gb = disk.used / (1024**3)
            disk_total_gb = disk.total / (1024**3)
            disk_free_gb = disk.free / (1024**3)
            self.lbl_disk_val.set_label(f"{disk_used_gb:.1f} GB / {disk_total_gb:.1f} GB")
            self.prog_disk.set_fraction(max(0.0, min(1.0, disk.percent / 100.0)))
            self.lbl_disk_sub.set_label(f"Capacidad Total: {disk_total_gb:.1f} GB  |  Libre: {disk_free_gb:.1f} GB ({disk.percent:.1f}%)")

        except Exception as e:
            print(f"Error updating stats: {e}", file=sys.stderr)

        return True

class PocoDashboardApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="org.poco.Dashboard")

    def do_startup(self):
        Adw.Application.do_startup(self)
        
        # Load custom dark CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS_DATA)
        display = Gdk.Display.get_default()
        if display:
            Gtk.StyleContext.add_provider_for_display(
                display,
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = PocoDashboardWindow(application=self)
        win.present()

if __name__ == "__main__":
    os.environ.setdefault("GSK_RENDERER", "cairo")
    os.environ.setdefault("GTK_A11Y", "none")
    app = PocoDashboardApp()
    app.run(sys.argv)
