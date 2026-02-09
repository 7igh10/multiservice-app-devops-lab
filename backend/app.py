# -*- coding: utf-8 -*-
#Тест
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/version")
def version():
    return jsonify({
	"version": os.getenv("APP_VERSION", "unknown"),
	"color": os.getenv("COLOR", "unknown")
    })

@app.route("/health")
def health():
    return "OK", 200

@app.route("/")
def hello():
    return "Hello from backend! v2 Или же привет"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
