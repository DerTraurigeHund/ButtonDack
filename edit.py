import customtkinter as ctk
import json
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk
import os

# JSON-Datei und Bildordner
JSON_FILE = "/home/luis/Project/button.json"
IMAGE_FOLDER = "/home/luis/Project/static/images"

class ButtonEditorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Button Editor")
        self.geometry("800x600")

        # JSON-Daten laden
        self.data = self.load_json(JSON_FILE)
        
        # GUI-Elemente
        self.create_widgets()
        
    def load_json(self, filepath):
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
            return data
        except FileNotFoundError:
            messagebox.showerror("Error", f"File {filepath} not found!")
            return {}
        except json.JSONDecodeError:
            messagebox.showerror("Error", "JSON file is corrupted!")
            return {}

    def save_json(self):
        try:
            with open(JSON_FILE, 'w') as f:
                json.dump(self.data, f, indent=4)
            messagebox.showinfo("Info", "Changes saved successfully!")
        except Exception as e:
            messagebox.showerror("Error", f"Could not save file:\n{e}")

    def create_widgets(self):
        # Auswahlfeld für Kategorien
        self.category_var = ctk.StringVar()
        self.category_menu = ctk.CTkOptionMenu(self, values=list(self.data.keys()), variable=self.category_var, command=self.load_buttons)
        self.category_menu.pack(pady=20)

        # Scrollbares Frame für Buttons
        self.button_frame = ctk.CTkScrollableFrame(self)  # Anpassung: scrollbares Frame
        self.button_frame.pack(fill="both", expand=True, padx=10, pady=10)

        # Button zum Speichern
        self.save_button = ctk.CTkButton(self, text="Save Changes", command=self.save_json)
        self.save_button.pack(pady=20)

    def load_buttons(self, category):
        for widget in self.button_frame.winfo_children():
            widget.destroy()  # Entferne alte Buttons
            
        buttons = self.data[category]
        
        for button_key, button_data in buttons.items():
            row_index = int(button_key[6:])
            
            # Name-Feld
            name_label = ctk.CTkLabel(self.button_frame, text="Name")
            name_label.grid(row=row_index, column=0, padx=5, pady=5)
            name_entry = ctk.CTkEntry(self.button_frame)
            name_entry.grid(row=row_index, column=1, padx=5, pady=5)
            name_entry.insert(0, button_data["name"])

            # Command-Feld
            command_label = ctk.CTkLabel(self.button_frame, text="Command")
            command_label.grid(row=row_index, column=2, padx=5, pady=5)
            command_entry = ctk.CTkEntry(self.button_frame)
            command_entry.grid(row=row_index, column=3, padx=5, pady=5)
            command_entry.insert(0, button_data["action"]["command"])

            # Hotkey-Feld
            hotkey_label = ctk.CTkLabel(self.button_frame, text="Hotkey")
            hotkey_label.grid(row=row_index, column=4, padx=5, pady=5)
            hotkey_entry = ctk.CTkEntry(self.button_frame)
            hotkey_entry.grid(row=row_index, column=5, padx=5, pady=5)
            hotkey_entry.insert(0, str(button_data["action"]["hotkey"]))

            # Bildanzeige
            image_path = os.path.join(IMAGE_FOLDER, button_data["image"])
            image = self.load_image(image_path)
            image_label = ctk.CTkLabel(self.button_frame, image=image)
            image_label.image = image  # Referenz behalten
            image_label.grid(row=row_index, column=6, padx=5, pady=5)

            # Bildauswahl
            select_image_button = ctk.CTkButton(self.button_frame, text="Choose Image", command=lambda key=button_key: self.select_image(key))
            select_image_button.grid(row=row_index, column=7, padx=5, pady=5)

            # Checkbox für Fehleroption
            error_var = ctk.BooleanVar(value=button_data["with_error"])
            error_checkbox = ctk.CTkCheckBox(self.button_frame, text="With Error", variable=error_var)
            error_checkbox.grid(row=row_index, column=8, padx=5, pady=5)

            # Hinzufügen des Eintrags zur Bearbeitung
            self.create_editable_button(button_key, name_entry, command_entry, hotkey_entry, error_var, category)
        
    def create_editable_button(self, key, name_entry, command_entry, hotkey_entry, error_var, category):
        def update_data():
            self.data[category][key]["name"] = name_entry.get()
            self.data[category][key]["action"]["command"] = command_entry.get()
            self.data[category][key]["hotkey"] = hotkey_entry.get()
            self.data[category][key]["with_error"] = error_var.get()
        
        # Bind changes to each entry
        name_entry.bind("<FocusOut>", lambda e: update_data())
        command_entry.bind("<FocusOut>", lambda e: update_data())
        hotkey_entry.bind("<FocusOut>", lambda e: update_data())
        error_var.trace_add("write", lambda *args: update_data())

    def load_image(self, path):
        """Load an image and resize it to fit in the UI."""
        if not os.path.exists(path):
            return None
        image = Image.open(path)
        image.thumbnail((50, 50))  # Resizing the image to fit the label
        return ImageTk.PhotoImage(image)

    def select_image(self, button_key):
        """Open a file dialog to select a new image and update the JSON data."""
        filepath = filedialog.askopenfilename(initialdir=IMAGE_FOLDER, title="Select Image", filetypes=(("PNG files", "*.png"), ("All files", "*.*")))
        if filepath:
            filename = os.path.basename(filepath)
            category = self.category_var.get()
            self.data[category][button_key]["image"] = filename
            self.load_buttons(category)  # Refresh buttons to show the new image


if __name__ == "__main__":
    ctk.set_appearance_mode("dark")  # Dark mode für CustomTkinter
    ctk.set_default_color_theme("blue")  # Blue color theme
    
    app = ButtonEditorApp()
    app.mainloop()
