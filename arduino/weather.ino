// Weather Station Device
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>

// WiFi Credentials
// WiFi Credentials
const char* ssid = "Target Group Ltd 5G 1";
const char* password = "TGLTD2020";

// Railway API
const char* serverUrl = "https://greenhouse.up.railway.app/api/v1/device-logs/sensor-data/";

const char* apiKey = "081764e1336ce6c3276fc668c3963051";
const char* deviceID = "681399e058e06969a4a13c2f"; // Replace with your weather device ID

// Sensor pins
#define DHTPIN 15
#define DHTTYPE DHT11
#define RAIN_PIN 35
#define LDR_PIN 33
#define IR_PIN 32  // IR sensor for wind speed

// LCD Setup
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Custom LCD characters
byte degreeSymbol[8] = {
  0b00110,
  0b01001,
  0b01001,
  0b00110,
  0b00000,
  0b00000,
  0b00000,
  0b00000
};

byte droplet[8] = {
  0b00100,
  0b00100,
  0b01010,
  0b01010,
  0b10001,
  0b10001,
  0b01110,
  0b00000
};

byte windSymbol[8] = {
  0b00000,
  0b00100,
  0b00110,
  0b11111,
  0b00110,
  0b00100,
  0b00000,
  0b00000
};

DHT dht(DHTPIN, DHTTYPE);
volatile int pulseCount = 0;
unsigned long lastUpdateTime = 0;
const unsigned long updateInterval = 5000;  // 5 seconds
bool wifiConnected = false;

void IRAM_ATTR countPulse() {
  pulseCount++;
}

void setup() {
  Serial.begin(115200);
  
  // Initialize DHT sensor
  dht.begin();
  
  // Initialize LCD
  lcd.init();
  lcd.backlight();
  lcd.createChar(0, degreeSymbol);
  lcd.createChar(1, droplet);
  lcd.createChar(2, windSymbol);
  
  // Show boot screen
  displayBootScreen();
  
  // Setup pins
  pinMode(LDR_PIN, INPUT);
  pinMode(IR_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(IR_PIN), countPulse, FALLING);
  
  // Connect to WiFi
  connectWiFi();
}

void loop() {
  unsigned long currentTime = millis();
  if (currentTime - lastUpdateTime >= updateInterval) {
    // Read DHT sensor
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    
    // Read rain sensor
    int rainValue = analogRead(RAIN_PIN);
    int rainPercent = map(rainValue, 0, 4095, 100, 0);  // lower value = more rain
    
    // Day or night
    int ldrValue = digitalRead(LDR_PIN);
    bool isDay = (ldrValue == LOW);
    String dayStatus = isDay ? "Day" : "Night";
    
    // Wind speed calculation
    pulseCount = 0;
    delay(1000);  // count pulses in 1 second
    int pulsesPerSecond = pulseCount;
    
    // Assuming 1 pulse = 1 rotation = 2.4 km/h (adjust for your anemometer)
    float windSpeed = pulsesPerSecond * 2.4;
    
    // Update displays
    updateLCD(temperature, humidity, dayStatus, windSpeed);
    printSerialData(temperature, humidity, rainPercent, dayStatus, windSpeed);
    
    // Send data to server
    if (wifiConnected) {
      sendWeatherData(temperature, humidity, windSpeed, isDay, rainPercent);
    }
    
    lastUpdateTime = currentTime;
  }
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED && wifiConnected) {
    wifiConnected = false;
    displayWiFiError();
  } else if (WiFi.status() == WL_CONNECTED && !wifiConnected) {
    wifiConnected = true;
    displayWiFiConnected();
  }
}

void displayBootScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Weather Station");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");
  delay(2000);
}

void connectWiFi() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");
  
  WiFi.begin(ssid, password);
  int dots = 0;
  
  while (WiFi.status() != WL_CONNECTED && dots < 15) {
    delay(500);
    lcd.setCursor(dots, 1);
    lcd.print(".");
    dots++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    displayWiFiConnected();
  } else {
    displayWiFiError();
  }
}

void updateLCD(float temperature, float humidity, String dayStatus, float windSpeed) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("T:");
  lcd.print(temperature, 1);
  lcd.write(0);  // Degree symbol
  lcd.print("C H:");
  lcd.print(humidity, 0);
  lcd.print("%");
  
  lcd.setCursor(0, 1);
  lcd.print(dayStatus.substring(0, 1));
  lcd.print(" W:");
  lcd.print(windSpeed, 1);
  lcd.print("km/h");
  lcd.write(1);  // Droplet for rain
}

void printSerialData(float temperature, float humidity, int rainPercent, String dayStatus, float windSpeed) {
  Serial.println("\n=========================");
  Serial.println("Weather Station Data");
  Serial.println("=========================");
  Serial.printf("Temperature: %.1f°C\n", temperature);
  Serial.printf("Humidity: %.1f%%\n", humidity);
  Serial.printf("Rain: %d%%\n", rainPercent);
  Serial.printf("Light: %s\n", dayStatus.c_str());
  Serial.printf("Wind Speed: %.1f km/h\n", windSpeed);
  Serial.printf("WiFi Status: %s\n", wifiConnected ? "Connected" : "Disconnected");
  Serial.println("=========================\n");
}

void displayWiFiConnected() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connected!");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP().toString());
  delay(2000);
}

void displayWiFiError() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connection");
  lcd.setCursor(0, 1);
  lcd.print("Failed!");
  delay(2000);
}

void sendWeatherData(float temperature, float humidity, float windSpeed, bool isDay, int rainfall) {
  HTTPClient http;
  String fullUrl = String(serverUrl) + String(deviceID);
  
  http.begin(fullUrl.c_str());
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", apiKey);
  http.addHeader("Connection", "close");
  
  StaticJsonDocument<200> jsonDoc;
  jsonDoc["temperature"] = temperature;
  jsonDoc["humidity"] = humidity;
  jsonDoc["wind_speed"] = windSpeed;
  jsonDoc["is_day"] = isDay;
  jsonDoc["rainfall"] = rainfall;
  
  String jsonData;
  serializeJson(jsonDoc, jsonData);
  
  int httpResponseCode = http.POST(jsonData);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.printf("Server Response Code: %d\n", httpResponseCode);
    Serial.println("Response: " + response);
  } else {
    Serial.printf("HTTP Error: %d\n", httpResponseCode);
  }
  
http.end();
}