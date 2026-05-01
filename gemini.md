# 📚 Edu-Xpress AI Integration Context

## 🧠 Project Overview

Edu-Xpress is a book delivery mobile application.

### Tech Stack:

* Backend: Flask (Python)
* Database: SQLite with SQLAlchemy
* Frontend: Flutter (Dart)

---

## ⚙️ Existing Features

* User Authentication (Login/Signup)
* Product Listing (Books)
* Search Functionality
* Cart System
* Order Placement
* Razorpay Integration (Test Mode)

---

## 🎯 Goals

Integrate smart features into the app:

### 🤖 AI Chatbot

1. Answer user queries about books
2. Recommend books based on user needs
3. Help users search for books
4. (Future) Assist in cart and order operations

### 🗺️ Map-Based Address System

5. Allow users to save delivery addresses using a Map API with precise location selection (latitude & longitude)

---

## 🗺️ Map & Location Feature

### Objective:

Enable users to select and save their delivery address using an interactive map.

### Requirements:

* Integrate a Map API (Google Maps preferred or OpenStreetMap for free usage)
* Allow users to:

  * Pin their exact delivery location
  * Fetch latitude and longitude
  * Convert coordinates into a readable address (reverse geocoding)
  * Save address with coordinates

### Backend Changes:

* Modify Order or create Address model with:

  * latitude (Float)
  * longitude (Float)
  * full_address (String)

### API Example:

POST /save-address
{
"user_id": 1,
"address": "Near XYZ College, Lucknow",
"latitude": 26.8467,
"longitude": 80.9462
}

### Future Scope:

* Auto-detect current location
* Multiple saved addresses
* Map preview in order screen

---

## 🚫 Constraints

* Must use FREE AI APIs (NO OpenAI paid APIs)
* Prefer Google Gemini API (free tier)
* Keep backend lightweight
* Avoid major refactoring

---

## 🧩 Backend Structure

* app.py → main Flask app
* routes/ → API routes
* models/ → SQLAlchemy models
* uploads/ → static files

---

## 📱 Frontend Structure (Flutter)

* screens/ → UI screens
* widgets/ → reusable components
* main.dart → entry point

---

## 🛠️ What to Build (Phase-wise)

### Phase 1:

* Add `/chat` API using Gemini

### Phase 2:

* Build Flutter chat UI

### Phase 3:

* Integrate chatbot with product search

### Phase 4:

* Add map-based address selection

---

## 📡 Chat API Format

### Request:

POST /chat
{
"message": "Suggest me a Python book"
}

### Response:

{
"reply": "Here are some Python books you can try..."
}

---

## 📌 Instructions for AI

* Do NOT rewrite the full project
* Modify only necessary parts
* Keep code modular and clean
* Use Flask best practices
* Ensure compatibility with existing APIs

---

## 🧠 Notes

* This is a student project
* Prioritize simplicity
* Code should be easy to understand
