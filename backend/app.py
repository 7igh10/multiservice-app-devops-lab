# -*- coding: utf-8 -*-
#Тест
from flask import Flask
import os

app = Flask(__name__)

@app.route("/health")
def health():
    return "OK", 200

@app.route("/")
def hello():
    return "Hello from backend!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
