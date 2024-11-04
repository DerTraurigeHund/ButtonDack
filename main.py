from flask import Flask, render_template, request, jsonify
import json
import os
import pyautogui
import subprocess
import shlex
from pydub import AudioSegment
from pydub.playback import play
import threading
import logging

# Logging konfigurieren
logging.basicConfig(filename='/home/luis/Project/my_script.log', level=logging.INFO)

# Beispiel für eine log-Nachricht
logging.info('Script started')

# Füge hier dein Code hinzu


app = Flask(__name__)

def load_profiles():
    with open("/home/luis/Project/button.json") as file:
        return json.load(file)


def press_hotkey(hotkeys: list):
    for hotkey in hotkeys:
        pyautogui.hotkey(*hotkey)

def send_notification(title, message):
    try:
        # send notification using notify-send
        subprocess.run(['notify-send', title, message], check=True)
        
        # start a new thread for playing sound
        threading.Thread(target=play_sound).start()

    except subprocess.CalledProcessError as e:
        print(f"Error sending notification: {e}")

def play_sound():
    # Load and lower the volume of the sound
    sound = AudioSegment.from_mp3("/home/luis/Project/error.mp3")
    sound -= 6
    play(sound)


def run_command(command):
    try:
        result = subprocess.run(shlex.split(command), capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e}"



active_profile = list(load_profiles().keys())[0]

@app.route('/')
def index():
    profiles = load_profiles()
    return render_template('index.html', profiles=profiles, active_profile=active_profile)

@app.route('/set_profile', methods=['POST'])
def set_profile():
    global active_profile
    active_profile = request.json['profile']
    return jsonify(status="success")

@app.route('/action', methods=['POST'])
def action():
    data = request.json
    profile = data['profile']
    button_id = data['button_id']
    
    profiles = load_profiles()

    button = profiles[profile][button_id]
    command = button['action']['command']
    hotkeys = button['action'].get('hotkey', [])

    if hotkeys:
        press_hotkey(hotkeys)

    if command != "":
        output = run_command(f"{command}")
    else: output = "No command defined for button"

    if output.startswith("Error:") and button['with_error']:
        send_notification("Error", output)
        return jsonify(status="error", message=output)
    
    print(output)

    return jsonify(status="success", message="Action executed successfully")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
