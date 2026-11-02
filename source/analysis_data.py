"""Load the MATLAB export and reject inconsistent report inputs."""
import json
import math
from pathlib import Path


def load_results(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise ValueError(f"Missing {path}; run matlab/ntu_classroom_energy_analysis.m first") from exc
    try:
        if data["schema_version"] != 1:
            raise ValueError("Unsupported analysis schema")
        p, s = data["parameters"], data["summary"]

        def number(value, *, positive=False):
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError("Analysis values must be finite numbers")
            if value < 0 or (positive and value == 0):
                raise ValueError("Analysis values must be non-negative (denominators positive)")
            return value

        def equal(actual, expected):
            number(actual)
            if not math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-6):
                raise ValueError(f"Inconsistent analysis value: {actual} != {expected}")

        count = number(p["classroom_count"], positive=True)
        if count != int(count):
            raise ValueError("Classroom count must be an integer")
        price = number(p["electricity_price_yuan_kwh"], positive=True)
        carbon = number(p["carbon_factor_kg_kwh"], positive=True)
        investment = number(p["investment_yuan"], positive=True)
        equipment = data["equipment"]
        if [e["name"] for e in equipment] != ["照明", "风扇", "空调", "多媒体"]:
            raise ValueError("Expected lighting, fan, AC and multimedia rows in that order")
        for row in equipment:
            power = number(row["power_kw"])
            hours = number(row["annual_hours"])
            ratio = number(row["waste_ratio"])
            if ratio > 1:
                raise ValueError("Waste ratio must be in [0,1]")
            equal(row["annual_energy_kwh"], count * power * hours)
            equal(row["waste_energy_kwh"], row["annual_energy_kwh"] * ratio)
            equal(row["waste_cost_yuan"], row["waste_energy_kwh"] * price)
        total = number(s["annual_energy_kwh"], positive=True)
        waste = number(s["waste_energy_kwh"], positive=True)
        equal(total, sum(e["annual_energy_kwh"] for e in equipment))
        equal(waste, sum(e["waste_energy_kwh"] for e in equipment))
        equal(s["waste_cost_yuan"], waste * price)
        equal(s["waste_ratio"], waste / total)
        equal(s["waste_carbon_ton"], waste * carbon / 1000)
        scenarios = data["scenarios"]
        if [r["name"] for r in scenarios] != ["低情景", "中位情景", "高情景"]:
            raise ValueError("Expected low, median and high scenarios")
        for row in scenarios:
            energy = number(row["annual_energy_kwh"], positive=True)
            loss = number(row["waste_energy_kwh"])
            if loss > energy:
                raise ValueError("Scenario waste exceeds energy")
            equal(row["waste_ratio"], loss / energy)
        equal(scenarios[1]["annual_energy_kwh"], total)
        equal(scenarios[1]["waste_energy_kwh"], waste)
        if not data["benefits"]:
            raise ValueError("Expected at least one benefit scenario")
        for row in data["benefits"]:
            saving = number(row["saving_kwh"], positive=True)
            equal(row["benefit_yuan"], saving * price)
            equal(row["carbon_reduction_ton"], saving * carbon / 1000)
            equal(row["payback_years"], investment / (saving * price))
        return data
    except (KeyError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"Invalid analysis export structure: {path}") from exc
