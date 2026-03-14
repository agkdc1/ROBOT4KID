/**
 * NL2Bot — Train Node Firmware (Shinkansen)
 *
 * ESP32-CAM running as WiFi AP.
 * - Front camera MJPEG streaming on port 81
 * - DRV8833 single-channel motor control
 * - Horn buzzer
 * - LED headlight/taillight
 * - WebSocket command interface (TrainCommand packets)
 * - Status telemetry broadcast at 5Hz
 */

#include <Arduino.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <esp_camera.h>

#include "config.h"
#include "protocol.h"

// Camera pin definitions for AI-Thinker ESP32-CAM
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Horn tone frequency (Hz)
#define HORN_FREQ         800
#define HORN_CHANNEL      4

AsyncWebServer server(HTTP_PORT);
AsyncWebServer streamServer(STREAM_PORT);
AsyncWebSocket ws("/ws");

// State
int8_t  currentSpeed = 0;
bool    hornActive   = false;
uint8_t lightsState  = 0;  // 0=off, 1=head, 2=tail, 3=both

unsigned long lastTelemetry = 0;
const unsigned long TELEMETRY_INTERVAL_MS = 200;  // 5Hz

// ---- Camera ----

void setupCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;

    if (psramFound()) {
        config.frame_size = FRAME_SIZE;
        config.jpeg_quality = JPEG_QUALITY;
        config.fb_count = 2;
    } else {
        config.frame_size = FRAMESIZE_SVGA;
        config.jpeg_quality = 16;
        config.fb_count = 1;
    }

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x\n", err);
    }
}

// ---- Motor (DRV8833 single channel) ----

void setupMotor() {
    ledcAttach(MOTOR_AIN1, PWM_FREQ, PWM_RES);
    ledcAttach(MOTOR_AIN2, PWM_FREQ, PWM_RES);
}

void setSpeed(int8_t speed) {
    currentSpeed = constrain(speed, -100, 100);
    int pwm = map(abs(currentSpeed), 0, 100, 0, 255);
    if (currentSpeed > 0) {
        ledcWrite(MOTOR_AIN1, pwm);
        ledcWrite(MOTOR_AIN2, 0);
    } else if (currentSpeed < 0) {
        ledcWrite(MOTOR_AIN1, 0);
        ledcWrite(MOTOR_AIN2, pwm);
    } else {
        ledcWrite(MOTOR_AIN1, 0);
        ledcWrite(MOTOR_AIN2, 0);
    }
}

// ---- Horn ----

void setupHorn() {
    ledcAttach(HORN_PIN, HORN_FREQ, PWM_RES);
    ledcWrite(HORN_PIN, 0);
}

void setHorn(bool on) {
    hornActive = on;
    ledcWrite(HORN_PIN, on ? 128 : 0);
}

// ---- Lights ----

void setupLights() {
    pinMode(LED_HEAD_PIN, OUTPUT);
    pinMode(LED_TAIL_PIN, OUTPUT);
    digitalWrite(LED_HEAD_PIN, LOW);
    digitalWrite(LED_TAIL_PIN, LOW);
}

void setLights(uint8_t mode) {
    lightsState = mode & 0x03;
    digitalWrite(LED_HEAD_PIN, (lightsState & 0x01) ? HIGH : LOW);
    digitalWrite(LED_TAIL_PIN, (lightsState & 0x02) ? HIGH : LOW);
}

// ---- Command handling ----

void handleTrainCommand(const TrainCommand& cmd) {
    switch (cmd.type) {
        case CMD_TRAIN_DRIVE:
            setSpeed(cmd.speed);
            setHorn(cmd.horn);
            setLights(cmd.lights);
            break;
        case CMD_TRAIN_HORN:
            setHorn(cmd.horn);
            break;
        case CMD_TRAIN_LIGHTS:
            setLights(cmd.lights);
            break;
    }
}

void onWebSocketEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
    if (type == WS_EVT_DATA) {
        if (len == sizeof(TrainCommand)) {
            TrainCommand cmd;
            memcpy(&cmd, data, sizeof(TrainCommand));
            if (validate_train_command(cmd)) {
                handleTrainCommand(cmd);
            }
        }
    }
}

// ---- Telemetry ----

void sendTelemetry() {
    if (ws.count() == 0) return;

    TrainStatus status;
    status.header      = PACKET_HEADER;
    status.type        = CMD_TRAIN_STATUS;
    status.speed_actual = currentSpeed;
    status.battery_pct = 100;  // TODO: read actual battery ADC
    status.flags       = (hornActive ? 0x01 : 0x00)
                       | ((lightsState & 0x01) ? 0x02 : 0x00)
                       | ((lightsState & 0x02) ? 0x04 : 0x00);
    status.checksum    = compute_checksum((const uint8_t*)&status, sizeof(TrainStatus) - 1);

    ws.binaryAll((uint8_t*)&status, sizeof(TrainStatus));
}

// ---- Setup & Loop ----

void setup() {
    Serial.begin(115200);

    // WiFi AP
    WiFi.softAP(TRAIN_WIFI_SSID, TRAIN_WIFI_PASSWORD);
    Serial.printf("AP started: %s\n", TRAIN_WIFI_SSID);
    Serial.printf("IP: %s\n", WiFi.softAPIP().toString().c_str());

    // Camera
    setupCamera();

    // Motor
    setupMotor();

    // Horn
    setupHorn();

    // Lights
    setupLights();

    // WebSocket
    ws.onEvent(onWebSocketEvent);
    server.addHandler(&ws);

    // Health endpoint
    server.on("/health", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send(200, "application/json", "{\"node\":\"train\",\"status\":\"ok\"}");
    });

    // Status endpoint
    server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request) {
        char buf[128];
        snprintf(buf, sizeof(buf),
            "{\"speed\":%d,\"horn\":%s,\"lights\":%d}",
            currentSpeed, hornActive ? "true" : "false", lightsState);
        request->send(200, "application/json", buf);
    });

    server.begin();
    streamServer.begin();
    Serial.println("Train node ready.");
}

void loop() {
    // Broadcast telemetry at 5Hz
    unsigned long now = millis();
    if (now - lastTelemetry >= TELEMETRY_INTERVAL_MS) {
        lastTelemetry = now;
        sendTelemetry();
    }

    // WebSocket cleanup
    ws.cleanupClients();

    delay(10);
}
