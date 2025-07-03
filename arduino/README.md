# ESP32 Fingerprint Attendance System

This ESP32-based fingerprint attendance system integrates with your Node.js backend to provide automatic student enrollment, deletion, and attendance tracking.

## Features

- **Automatic Enrollment**: When a new student is created in the backend, the ESP32 automatically receives the command to enroll their fingerprint
- **Automatic Deletion**: When a student is deleted from the backend, the ESP32 automatically removes their fingerprint
- **Attendance Tracking**: When a student scans their fingerprint, attendance is automatically sent to the backend
- **Smart Time Detection**: Attendance type (enter/leave) is determined based on Somalia time (UTC+3) - before noon = enter, after noon = leave
- **Real-time Communication**: ESP32 polls the backend every 3 seconds for new commands
- **Visual Feedback**: LCD display and LED indicators for system status
- **Environmental Monitoring**: Temperature, humidity, and gas sensor readings

## Hardware Requirements

- ESP32 Development Board
- R307/R308 Fingerprint Sensor
- 16x2 I2C LCD Display
- DHT22 Temperature/Humidity Sensor
- MQ2 Gas Sensor
- GPS Module (optional)
- LEDs (Red and Green)
- Buzzer
- Breadboard and Jumper Wires

## Pin Connections

| Component          | ESP32 Pin                    | Description          |
| ------------------ | ---------------------------- | -------------------- |
| Fingerprint Sensor | GPIO 16 (RX), GPIO 17 (TX)   | UART2 communication  |
| LCD Display        | GPIO 21 (SDA), GPIO 22 (SCL) | I2C communication    |
| Red LED            | GPIO 12                      | Status indicator     |
| Green LED          | GPIO 13                      | Status indicator     |
| Buzzer             | GPIO 14                      | Audio feedback       |
| DHT22              | GPIO 19                      | Temperature/Humidity |
| Gas Sensor         | GPIO 18                      | Gas detection        |
| GPS                | GPIO 27 (RX), GPIO 26 (TX)   | GPS data             |

## Setup Instructions

### 1. Configure the System

Edit `config.h` file and update the following:

```cpp
// WiFi Configuration
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Backend Server Configuration
#define BACKEND_IP "YOUR_BACKEND_IP"  // Your backend server IP
#define BACKEND_PORT "6100"           // Your backend server port
```

### 2. Install Required Libraries

In Arduino IDE, install these libraries:

- `Adafruit Fingerprint Sensor Library`
- `LiquidCrystal I2C`
- `TinyGPS++`
- `DHT sensor library`
- `ArduinoJson`
- `WiFi` (built-in with ESP32)

### 3. Upload the Code

1. Open `fingerprint_system.ino` in Arduino IDE
2. Select your ESP32 board
3. Set the correct port
4. Upload the code

### 4. Backend Integration

The system works with your existing backend. Make sure:

1. Your backend is running on the specified IP and port
2. The ESP32 routes are properly configured
3. The fingerprint controller is integrated with your student management system

## How It Works

### Command Codes

- **Code 1**: Enroll new fingerprint
- **Code 2**: Delete fingerprint
- **Code 0**: No pending commands

### Workflow

1. **Student Creation**: When an admin creates a student in the Flutter app:

   - Backend generates a unique fingerprint ID (1-127)
   - Backend sets a pending command with code 1
   - ESP32 polls and receives the enrollment command
   - ESP32 guides the user through fingerprint enrollment
   - Student name is stored in EEPROM

2. **Student Deletion**: When an admin deletes a student:

   - Backend sets a pending command with code 2
   - ESP32 polls and receives the deletion command
   - ESP32 removes the fingerprint from the sensor
   - Student name is cleared from EEPROM

3. **Attendance Recording**: When a student scans their fingerprint:
   - ESP32 identifies the student
   - ESP32 sends fingerprint ID to backend
   - Backend calculates time (Somalia UTC+3)
   - Backend determines attendance type (enter/leave)
   - Backend creates attendance record

### Time-based Attendance Logic

- **Enter**: Before 12:00 PM (Somalia time)
- **Leave**: After 12:00 PM (Somalia time)

## API Endpoints

### Polling Endpoint

```
GET /api/esp32/fingerprint/poll
```

**Response for enrollment:**

```json
{
  "success": true,
  "message": "New student created - enroll fingerprint",
  "code": 1,
  "fingerprintId": 5,
  "studentName": "John Doe",
  "studentId": "64f8a1b2c3d4e5f6a7b8c9d0"
}
```

**Response for deletion:**

```json
{
  "success": true,
  "message": "Student deleted - remove fingerprint",
  "code": 2,
  "fingerprintId": 5,
  "studentName": "John Doe",
  "studentId": "64f8a1b2c3d4e5f6a7b8c9d0"
}
```

### Attendance Endpoint

```
POST /api/esp32/fingerprint/attendance
```

**Request:**

```json
{
  "fingerprintId": 5
}
```

**Response:**

```json
{
  "success": true,
  "message": "Attendance recorded: enter",
  "data": {
    "student": {
      "name": "John Doe",
      "fingerprintId": 5
    },
    "date": "2024-01-15T08:30:00.000Z",
    "time": "11:30:00",
    "type": "enter"
  }
}
```

## Troubleshooting

### Common Issues

1. **WiFi Connection Failed**

   - Check WiFi credentials in `config.h`
   - Ensure ESP32 is within WiFi range
   - Check if WiFi network supports 2.4GHz

2. **Backend Connection Failed**

   - Verify backend server is running
   - Check IP address and port in `config.h`
   - Ensure ESP32 and backend are on same network

3. **Fingerprint Sensor Not Working**

   - Check wiring connections
   - Verify sensor power supply
   - Check UART pins (GPIO 16, 17)

4. **LCD Not Displaying**
   - Check I2C address (try 0x27 or 0x3F)
   - Verify SDA/SCL connections
   - Check power supply

### Debug Information

The system provides detailed debug information via Serial Monitor:

- WiFi connection status
- Backend polling results
- Fingerprint operations
- Attendance submissions
- Sensor readings

## Security Considerations

- Store WiFi credentials securely
- Use HTTPS for production deployments
- Implement authentication for ESP32 endpoints
- Regularly update firmware
- Monitor system logs for suspicious activity

## Maintenance

- Clean fingerprint sensor regularly
- Check sensor connections periodically
- Monitor EEPROM usage
- Update backend integration as needed
- Backup student data regularly
