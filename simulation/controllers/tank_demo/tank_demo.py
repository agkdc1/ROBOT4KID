"""Tank demo controller — auto figure-8 pattern with turret rotation.

Drives the tank in a figure-8 pattern while rotating the turret,
for simulation video capture and physics evaluation.
"""

import math

try:
    from controller import Robot
except ImportError:
    Robot = None

TIMESTEP = 16  # ms


def main():
    robot = Robot()

    # Motors
    left_motor = robot.getDevice("left_motor")
    right_motor = robot.getDevice("right_motor")
    turret_motor = robot.getDevice("turret_motor")

    for motor in [left_motor, right_motor]:
        if motor:
            motor.setPosition(float("inf"))
            motor.setVelocity(0)

    if turret_motor:
        turret_motor.setPosition(float("inf"))
        turret_motor.setVelocity(0)

    # Figure-8 demo parameters
    base_speed = 4.0  # rad/s
    turn_diff = 3.0   # speed difference for turning
    phase_steps = 150  # steps per phase (~2.4 seconds)
    turret_speed = 0.5  # rad/s

    step_count = 0

    while robot.step(TIMESTEP) != -1:
        step_count += 1
        phase = (step_count // phase_steps) % 8

        # Figure-8: straight, left turn, straight, right turn, repeat mirrored
        if phase == 0:    # Straight forward
            left_v, right_v = base_speed, base_speed
        elif phase == 1:  # Turn left
            left_v, right_v = base_speed - turn_diff, base_speed + turn_diff
        elif phase == 2:  # Straight forward
            left_v, right_v = base_speed, base_speed
        elif phase == 3:  # Turn right
            left_v, right_v = base_speed + turn_diff, base_speed - turn_diff
        elif phase == 4:  # Straight forward
            left_v, right_v = base_speed, base_speed
        elif phase == 5:  # Turn right (completing figure-8)
            left_v, right_v = base_speed + turn_diff, base_speed - turn_diff
        elif phase == 6:  # Straight forward
            left_v, right_v = base_speed, base_speed
        else:             # Turn left
            left_v, right_v = base_speed - turn_diff, base_speed + turn_diff

        if left_motor:
            left_motor.setVelocity(left_v)
        if right_motor:
            right_motor.setVelocity(right_v)

        # Turret sweeps back and forth
        if turret_motor:
            t = step_count * TIMESTEP / 1000.0
            turret_motor.setVelocity(turret_speed * math.sin(t * 0.5))


if __name__ == "__main__":
    if Robot is not None:
        main()
    else:
        print("Run this inside Webots, not standalone.")
