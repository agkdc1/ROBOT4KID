"""Comprehensive integration tests for the NL2Bot system.

Runs against live Planning Server (port 8000) and Simulation Server (port 8100).

Usage:
    cd ROBOT4KID
    python -m pytest tests/test_integration.py -v
    python -m pytest tests/test_integration.py -v -k "not openscad"   # skip OpenSCAD tests
"""

import os
import shutil
import sys
import uuid
from pathlib import Path

import httpx
import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from dotenv import load_dotenv

load_dotenv(PROJECT_ROOT / ".env")

# Re-import conftest constants for direct use in markers
from tests.conftest import (
    PLANNING_URL,
    SIMULATION_URL,
    SIM_API_KEY,
    TEST_USERNAME,
)

# Detect OpenSCAD availability
OPENSCAD_BIN = os.getenv("OPENSCAD_BIN", "openscad")
HAS_OPENSCAD = shutil.which(OPENSCAD_BIN) is not None


# ===================================================================
# 1. Server Health
# ===================================================================


class TestServerHealth:
    """Both servers respond to health checks."""

    def test_planning_server_health(self, planning_url: str):
        resp = httpx.get(f"{planning_url}/api/v1/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "ok"
        assert body["service"] == "planning_server"

    def test_simulation_server_health(self, simulation_url: str):
        resp = httpx.get(f"{simulation_url}/api/v1/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "ok"
        assert body["service"] == "simulation_server"


# ===================================================================
# 2. Simulation Server Capabilities
# ===================================================================


class TestSimulationCapabilities:
    """GET /api/v1/capabilities returns expected features."""

    def test_capabilities_response(self, simulation_url: str):
        resp = httpx.get(f"{simulation_url}/api/v1/capabilities")
        assert resp.status_code == 200
        caps = resp.json()
        assert caps["render"] is True
        assert caps["assemble"] is True
        assert caps["physics"] is True
        assert caps["printability"] is True
        assert caps["viewer"] is True
        assert "ballistics_training" in caps

    def test_capabilities_no_auth_required(self, simulation_url: str):
        """Capabilities endpoint does not require API key."""
        resp = httpx.get(f"{simulation_url}/api/v1/capabilities")
        assert resp.status_code == 200


# ===================================================================
# 3. Auth Flow
# ===================================================================


class TestAuthFlow:
    """Full JWT authentication lifecycle."""

    def test_admin_login(self, planning_url: str, admin_token: str):
        """Admin can log in and get a valid JWT."""
        assert admin_token  # non-empty string
        # Verify token works
        resp = httpx.get(
            f"{planning_url}/api/v1/auth/me",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        me = resp.json()
        assert me["role"] == "admin"
        assert me["status"] == "approved"

    def test_register_approve_login(self, planning_url: str, test_user_token: str):
        """Register -> admin approve -> user login returns valid JWT."""
        assert test_user_token
        resp = httpx.get(
            f"{planning_url}/api/v1/auth/me",
            headers={"Authorization": f"Bearer {test_user_token}"},
        )
        assert resp.status_code == 200
        me = resp.json()
        assert me["username"] == TEST_USERNAME
        assert me["role"] == "user"
        assert me["status"] == "approved"

    def test_duplicate_registration_fails(self, planning_url: str, test_user_token: str):
        """Registering the same username twice returns 400."""
        # test_user_token fixture already registered TEST_USERNAME
        resp = httpx.post(
            f"{planning_url}/api/v1/auth/register",
            json={"username": TEST_USERNAME, "password": "anotherpass123"},
        )
        assert resp.status_code == 400
        assert "already registered" in resp.json()["detail"].lower()

    def test_login_unapproved_user_fails(self, planning_url: str):
        """A newly registered (pending) user cannot log in."""
        unapproved_name = f"unapproved_{uuid.uuid4().hex[:8]}"
        httpx.post(
            f"{planning_url}/api/v1/auth/register",
            json={"username": unapproved_name, "password": "testpass123"},
        )
        resp = httpx.post(
            f"{planning_url}/api/v1/auth/login",
            data={"username": unapproved_name, "password": "testpass123"},
        )
        assert resp.status_code == 403
        assert "not approved" in resp.json()["detail"].lower()

    def test_invalid_credentials_fail(self, planning_url: str):
        resp = httpx.post(
            f"{planning_url}/api/v1/auth/login",
            data={"username": "nonexistent", "password": "wrong"},
        )
        assert resp.status_code == 401

    def test_missing_token_rejected(self, planning_url: str):
        """Endpoints requiring auth reject requests without a token."""
        resp = httpx.get(f"{planning_url}/api/v1/projects")
        assert resp.status_code in (401, 403)


# ===================================================================
# 4. Project CRUD
# ===================================================================


class TestProjectCRUD:
    """Create, list, get, update, and delete projects."""

    def test_create_project(self, planning_url: str, user_headers: dict):
        resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Integration Test Project", "description": "Created by test suite"},
        )
        assert resp.status_code == 201
        project = resp.json()
        assert project["name"] == "Integration Test Project"
        assert project["status"] == "active" or "status" in project

    def test_list_projects(self, planning_url: str, user_headers: dict):
        # Ensure at least one project exists
        httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": f"List Test {uuid.uuid4().hex[:6]}"},
        )
        resp = httpx.get(f"{planning_url}/api/v1/projects", headers=user_headers)
        assert resp.status_code == 200
        projects = resp.json()
        assert isinstance(projects, list)
        assert len(projects) >= 1

    def test_get_project(self, planning_url: str, user_headers: dict):
        # Create then fetch
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Get Test Project"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.get(
            f"{planning_url}/api/v1/projects/{project_id}",
            headers=user_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["id"] == project_id

    def test_update_project(self, planning_url: str, user_headers: dict):
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Update Test"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.put(
            f"{planning_url}/api/v1/projects/{project_id}",
            headers=user_headers,
            json={"name": "Updated Name", "description": "Updated desc"},
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Name"

    def test_delete_project(self, planning_url: str, user_headers: dict):
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Delete Me"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.delete(
            f"{planning_url}/api/v1/projects/{project_id}",
            headers=user_headers,
        )
        assert resp.status_code == 200

        # Verify deleted
        resp = httpx.get(
            f"{planning_url}/api/v1/projects/{project_id}",
            headers=user_headers,
        )
        assert resp.status_code == 404

    def test_get_nonexistent_project_returns_404(self, planning_url: str, user_headers: dict):
        resp = httpx.get(
            f"{planning_url}/api/v1/projects/999999",
            headers=user_headers,
        )
        assert resp.status_code == 404


# ===================================================================
# 5. Schema Validation
# ===================================================================


class TestSchemaValidation:
    """Pydantic schema validation for core data contracts."""

    def test_universal_command_tank(self):
        from shared.schemas.command_spec import UniversalCommand, DriveMode, ModelType

        cmd = UniversalCommand(
            model_type=ModelType.TANK,
            drive_mode=DriveMode.DIFFERENTIAL,
            left_speed=50,
            right_speed=-30,
            turret_angle=1800,
            barrel_elevation=10,
            fire=True,
        )
        assert cmd.model_type == ModelType.TANK
        assert cmd.drive_mode == DriveMode.DIFFERENTIAL
        assert cmd.left_speed == 50
        assert cmd.right_speed == -30
        assert cmd.fire is True

    def test_universal_command_train(self):
        from shared.schemas.command_spec import UniversalCommand, DriveMode, ModelType

        cmd = UniversalCommand(
            model_type=ModelType.TRAIN,
            drive_mode=DriveMode.SIMPLE,
            speed=75,
            horn=True,
            lights=3,
        )
        assert cmd.model_type == ModelType.TRAIN
        assert cmd.speed == 75
        assert cmd.horn is True
        assert cmd.lights == 3

    def test_universal_command_validation_bounds(self):
        from shared.schemas.command_spec import UniversalCommand, DriveMode, ModelType
        from pydantic import ValidationError

        # Speed out of range
        with pytest.raises(ValidationError):
            UniversalCommand(
                model_type=ModelType.TANK,
                drive_mode=DriveMode.DIFFERENTIAL,
                left_speed=200,  # exceeds 100
            )

    def test_robot_spec_tank(self):
        from shared.schemas.robot_spec import RobotSpec, ModelType, PartSpec

        spec = RobotSpec(
            name="Test Tank",
            model_type=ModelType.TANK,
            parts=[
                PartSpec(
                    id="hull",
                    name="Hull",
                    scad_file="hull.scad",
                    category="chassis",
                    dimensions_mm=(150.0, 100.0, 60.0),
                )
            ],
        )
        assert spec.model_type == ModelType.TANK
        assert len(spec.parts) == 1
        assert spec.parts[0].id == "hull"

    def test_robot_spec_train(self):
        from shared.schemas.robot_spec import RobotSpec, ModelType, PartSpec

        spec = RobotSpec(
            name="Test Train",
            model_type=ModelType.TRAIN,
            parts=[
                PartSpec(
                    id="locomotive",
                    name="Locomotive Body",
                    scad_file="locomotive.scad",
                    category="body",
                    dimensions_mm=(100.0, 30.0, 35.0),
                )
            ],
        )
        assert spec.model_type == ModelType.TRAIN
        assert spec.parts[0].id == "locomotive"

    def test_simulation_request_schema(self):
        from shared.schemas.simulation_request import SimulationRequest
        from shared.schemas.robot_spec import RobotSpec, ModelType

        req = SimulationRequest(
            job_id="test-job-001",
            robot_spec=RobotSpec(name="Minimal", model_type=ModelType.TANK),
            simulation_type="render",
        )
        assert req.job_id == "test-job-001"
        assert req.simulation_type == "render"
        assert req.robot_spec.name == "Minimal"

    def test_simulation_feedback_schema(self):
        from shared.schemas.simulation_feedback import (
            SimulationFeedback,
            FeedbackItem,
            SeverityLevel,
        )

        feedback = SimulationFeedback(
            job_id="test-001",
            status="completed",
            feedback_items=[
                FeedbackItem(
                    severity=SeverityLevel.INFO,
                    category="render",
                    message="All parts rendered successfully.",
                )
            ],
            overall_score=0.95,
        )
        assert feedback.status == "completed"
        assert len(feedback.feedback_items) == 1
        assert feedback.overall_score == 0.95


# ===================================================================
# 6. Simulation Request (requires OpenSCAD)
# ===================================================================


class TestSimulationRequest:
    """Send a simulation request to the simulation server."""

    @pytest.mark.skipif(not HAS_OPENSCAD, reason="OpenSCAD not installed")
    def test_submit_minimal_simulation(self, simulation_url: str, sim_headers: dict):
        """Submit a minimal SimulationRequest with a simple cube SCAD."""
        from shared.schemas.robot_spec import RobotSpec, ModelType, PartSpec

        job_id = f"inttest-{uuid.uuid4().hex[:8]}"
        spec = RobotSpec(
            name="Integration Test Cube",
            model_type=ModelType.TANK,
            parts=[
                PartSpec(
                    id="test_cube",
                    name="Test Cube",
                    scad_file="test_cube.scad",
                    scad_code='$fn=32;\ncube([20, 20, 20], center=true);',
                    category="chassis",
                    dimensions_mm=(20.0, 20.0, 20.0),
                )
            ],
        )

        payload = {
            "job_id": job_id,
            "robot_spec": spec.model_dump(),
            "simulation_type": "render",
        }

        resp = httpx.post(
            f"{simulation_url}/api/v1/simulate",
            headers=sim_headers,
            json=payload,
            timeout=30,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["job_id"] == job_id
        assert body["status"] == "queued"

    @pytest.mark.skipif(not HAS_OPENSCAD, reason="OpenSCAD not installed")
    def test_get_job_status(self, simulation_url: str, sim_headers: dict):
        """Submit a job and then query its status."""
        from shared.schemas.robot_spec import RobotSpec, ModelType, PartSpec

        job_id = f"inttest-status-{uuid.uuid4().hex[:8]}"
        spec = RobotSpec(
            name="Status Test",
            model_type=ModelType.TANK,
            parts=[
                PartSpec(
                    id="status_cube",
                    name="Status Cube",
                    scad_file="status_cube.scad",
                    scad_code='cube([10,10,10]);',
                    category="chassis",
                    dimensions_mm=(10.0, 10.0, 10.0),
                )
            ],
        )

        httpx.post(
            f"{simulation_url}/api/v1/simulate",
            headers=sim_headers,
            json={
                "job_id": job_id,
                "robot_spec": spec.model_dump(),
                "simulation_type": "render",
            },
            timeout=30,
        )

        resp = httpx.get(
            f"{simulation_url}/api/v1/jobs/{job_id}",
            headers=sim_headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["job_id"] == job_id
        assert body["status"] in ("queued", "running", "completed", "failed")

    def test_simulation_server_requires_api_key(self, simulation_url: str, sim_api_key: str):
        """Protected endpoints reject requests without a valid API key (when key is set)."""
        if not sim_api_key:
            pytest.skip("SIM_API_KEY not set; auth disabled in dev mode")

        resp = httpx.get(f"{simulation_url}/api/v1/jobs/nonexistent")
        assert resp.status_code == 401

    def test_nonexistent_job_returns_404(self, simulation_url: str, sim_headers: dict):
        resp = httpx.get(
            f"{simulation_url}/api/v1/jobs/no-such-job-{uuid.uuid4().hex}",
            headers=sim_headers,
        )
        assert resp.status_code == 404


# ===================================================================
# 7. Pipeline Dry Run
# ===================================================================


class TestPipelineDryRun:
    """Verify pipeline endpoints exist and validate input."""

    def test_pipeline_run_rejects_empty_prompt(
        self, planning_url: str, user_headers: dict
    ):
        """Pipeline endpoint rejects a prompt shorter than min_length."""
        # First create a project to use
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Pipeline Dry Run"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.post(
            f"{planning_url}/api/v1/projects/{project_id}/pipeline/run",
            headers=user_headers,
            json={"prompt": ""},  # empty — should fail validation (min_length=10)
        )
        assert resp.status_code == 422  # Pydantic validation error

    def test_pipeline_run_rejects_short_prompt(
        self, planning_url: str, user_headers: dict
    ):
        """Pipeline rejects prompts under 10 characters."""
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Pipeline Short Prompt"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.post(
            f"{planning_url}/api/v1/projects/{project_id}/pipeline/run",
            headers=user_headers,
            json={"prompt": "short"},
        )
        assert resp.status_code == 422

    def test_pipeline_status_not_started(
        self, planning_url: str, user_headers: dict
    ):
        """Pipeline status for a project with no run returns not_started."""
        create_resp = httpx.post(
            f"{planning_url}/api/v1/projects",
            headers=user_headers,
            json={"name": "Pipeline Status Test"},
        )
        project_id = create_resp.json()["id"]

        resp = httpx.get(
            f"{planning_url}/api/v1/projects/{project_id}/pipeline/status",
            headers=user_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "not_started"

    def test_pipeline_requires_auth(self, planning_url: str):
        """Pipeline endpoints reject unauthenticated requests."""
        resp = httpx.post(
            f"{planning_url}/api/v1/projects/1/pipeline/run",
            json={"prompt": "build a robot tank with treads"},
        )
        assert resp.status_code in (401, 403)


# ===================================================================
# 8. FCS Endpoints
# ===================================================================


class TestFCSEndpoints:
    """Fire control system coefficient and shot endpoints."""

    def test_get_coefficients(self, planning_url: str):
        resp = httpx.get(f"{planning_url}/api/v1/fcs/coefficients")
        assert resp.status_code == 200
        coeffs = resp.json()
        # Should have the 5 tunable coefficients
        for key in ("gravity_factor", "drag_factor", "hopup_factor", "motion_factor", "bias"):
            assert key in coeffs, f"Missing coefficient: {key}"

    def test_upload_empty_shots(self, planning_url: str):
        resp = httpx.post(
            f"{planning_url}/api/v1/fcs/shots",
            json={"shots": []},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["received"] == 0

    def test_train_without_data_fails(self, planning_url: str):
        """Training with no buffered shots returns 400."""
        # Clear buffer first
        httpx.delete(f"{planning_url}/api/v1/fcs/shots")
        resp = httpx.post(f"{planning_url}/api/v1/fcs/train")
        assert resp.status_code == 400
        assert "no shot data" in resp.json()["detail"].lower()

    def test_clear_shots(self, planning_url: str):
        resp = httpx.delete(f"{planning_url}/api/v1/fcs/shots")
        assert resp.status_code == 200
        assert "cleared" in resp.json()


# ===================================================================
# 9. Config Loading
# ===================================================================


class TestConfigLoading:
    """Verify hardware_specs.yaml loads correctly."""

    def test_hardware_config_loads(self):
        from shared.hardware_config import load_hardware_config

        # Clear cache to force fresh load
        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        assert isinstance(hw, dict)
        assert len(hw) > 0

    def test_hardware_config_has_printer_section(self):
        from shared.hardware_config import load_hardware_config

        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        assert "printer" in hw
        assert hw["printer"]["name"] == "Bambu Lab A1 Mini"
        assert hw["printer"]["build_volume_mm"] == [180, 180, 180]

    def test_hardware_config_has_tank_section(self):
        from shared.hardware_config import load_hardware_config

        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        assert "tank" in hw
        assert "chassis" in hw["tank"]
        assert hw["tank"]["chassis"]["length_mm"] == 300

    def test_hardware_config_has_fasteners_section(self):
        from shared.hardware_config import load_hardware_config

        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        assert "fasteners" in hw
        assert "m4" in hw["fasteners"]
        assert "m3" in hw["fasteners"]
        assert hw["fasteners"]["m4"]["hole_diameter_mm"] == 4.4

    def test_hardware_config_has_components_section(self):
        from shared.hardware_config import load_hardware_config

        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        assert "components" in hw
        esp32_cam = hw.get_component("esp32_cam")
        assert esp32_cam, "esp32_cam component not found in hardware_specs.yaml"

    def test_hardware_config_attribute_access(self):
        from shared.hardware_config import load_hardware_config

        load_hardware_config.cache_clear()
        hw = load_hardware_config()
        # Attribute-style access should work
        assert hw.printer.name == "Bambu Lab A1 Mini"
        assert hw.tank.chassis.length_mm == 300

    def test_yaml_file_exists(self):
        config_path = PROJECT_ROOT / "config" / "hardware_specs.yaml"
        assert config_path.exists(), f"hardware_specs.yaml not found at {config_path}"
