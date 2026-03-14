#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <stdint.h>

// Command packet header
#define PACKET_HEADER 0xAA

// Command types
#define CMD_MOVE      0x01
#define CMD_TURRET    0x02
#define CMD_FIRE      0x03
#define CMD_CAMERA    0x04
#define CMD_STATUS    0x05
#define CMD_HEARTBEAT 0x06

// Camera modes
#define CAM_DRIVER  0
#define CAM_GUNNER  1
#define CAM_SPLIT   2

#pragma pack(push, 1)

struct TankCommand {
    uint8_t  header;           // 0xAA
    uint8_t  type;             // CMD_MOVE, CMD_TURRET, etc.
    int8_t   left_speed;       // -100 to +100 (differential drive)
    int8_t   right_speed;      // -100 to +100
    int16_t  turret_angle;     // 0-3600 (degrees x10 for precision)
    int8_t   barrel_elevation; // -10 to +45 degrees
    uint8_t  fire;             // 0 or 1
    uint8_t  camera_mode;      // CAM_DRIVER, CAM_GUNNER, CAM_SPLIT
    uint8_t  checksum;         // XOR of all preceding bytes
};

struct TankStatus {
    uint8_t  header;           // 0xAA
    uint8_t  type;             // CMD_STATUS
    int16_t  heading;          // 0-3600 (degrees x10)
    int16_t  pitch;            // degrees x10
    int16_t  roll;             // degrees x10
    uint16_t range_mm;         // ToF distance in mm
    uint8_t  battery_pct;      // 0-100
    uint8_t  checksum;
};

#pragma pack(pop)

// Compute XOR checksum over a buffer
inline uint8_t compute_checksum(const uint8_t* data, size_t len) {
    uint8_t cs = 0;
    for (size_t i = 0; i < len; i++) {
        cs ^= data[i];
    }
    return cs;
}

// Validate a command packet
inline bool validate_command(const TankCommand& cmd) {
    if (cmd.header != PACKET_HEADER) return false;
    uint8_t cs = compute_checksum((const uint8_t*)&cmd, sizeof(TankCommand) - 1);
    return cs == cmd.checksum;
}

#endif // PROTOCOL_H
