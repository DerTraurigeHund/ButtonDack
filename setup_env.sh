#!/bin/bash

# Überprüfen, ob Python und pip installiert sind
if ! command -v python3 &> /dev/null; then
    echo "Python3 ist nicht installiert. Bitte installiere Python3."
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo "pip3 ist nicht installiert. Bitte installiere pip3."
    exit 1
fi

# Virtuelle Umgebung erstellen
python3 -m venv venv
echo "Virtuelle Umgebung 'venv' erstellt."

# Aktivieren der virtuellen Umgebung
source venv/bin/activate
echo "Virtuelle Umgebung aktiviert."

# Installieren der Bibliotheken aus requirements.txt
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
    echo "Bibliotheken installiert."
else
    echo "requirements.txt Datei wurde nicht gefunden."
    deactivate
    exit 1
fi

# Deaktivieren der virtuellen Umgebung
deactivate
echo "Virtuelle Umgebung deaktiviert."
