"""Train controller for Webots — simple speed control demo.

Drives a Plarail-compatible train forward, then reverses, in a loop.
For physics simulation testing and video capture.
"""

try:
    from controller import Robot
except ImportError:
    Robot = None

TIMESTEP = 16  # ms

def main():
    robot = Robot()

    # Get motor devices
    left_motor = robot.getDevice("left_motor")
    right_motor = robot.getDevice("right_motor")

    if left_motor:
        left_motor.setPosition(float("inf"))  # Velocity control mode
        left_motor.setVelocity(0)
    if right_motor:
        right_motor.setPosition(float("inf"))
        right_motor.setVelocity(0)

    # Simple demo: drive forward, pause, reverse, pause, repeat
    speed = 5.0  # rad/s
    phase = 0
    step_count = 0
    phase_duration = 200  # steps (~3.2 seconds at 16ms)

    while robot.step(TIMESTEP) != -1:
        step_count += 1

        if step_count % phase_duration == 0:
            phase = (phase + 1) % 4

        if phase == 0:
            # Forward
            v = speed
        elif phase == 1:
            # Stop
            v = 0
        elif phase == 2:
            # Reverse
            v = -speed
        else:
            # Stop
            v = 0

        if left_motor:
            left_motor.setVelocity(v)
        if right_motor:
            right_motor.setVelocity(v)


if __name__ == "__main__":
    if Robot is not None:
        main()
    else:
        print("Run this inside Webots, not standalone.")
