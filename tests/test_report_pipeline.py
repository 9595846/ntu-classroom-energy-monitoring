import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from docx import Document

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "source"))
from analysis_data import load_results
import build_report


class ReportPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = load_results(ROOT / "matlab" / "analysis_results.json")

    def write(self, root, data):
        path = root / "results.json"
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        return path

    def test_matlab_export_matches_known_baseline(self):
        self.assertAlmostEqual(self.baseline["summary"]["annual_energy_kwh"], 3830057.5)
        self.assertAlmostEqual(self.baseline["summary"]["waste_energy_kwh"], 507832.475)

    def test_rejects_stale_summary_before_writing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = copy.deepcopy(self.baseline)
            data["summary"]["annual_energy_kwh"] += 100
            output = root / "new-directory" / "report.docx"
            with self.assertRaisesRegex(ValueError, "Inconsistent"):
                build_report.build(self.write(root, data), output)
            self.assertFalse(output.parent.exists())

    def test_rejects_nonfinite_and_missing_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = copy.deepcopy(self.baseline)
            data["parameters"]["electricity_price_yuan_kwh"] = float("nan")
            with self.assertRaisesRegex(ValueError, "finite"):
                load_results(self.write(root, data))
            with self.assertRaisesRegex(ValueError, "run matlab"):
                load_results(root / "missing.json")

    def test_changed_tariff_updates_report_tables_and_prose(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = copy.deepcopy(self.baseline)
            price = 1.2
            data["parameters"]["electricity_price_yuan_kwh"] = price
            for row in data["equipment"]:
                row["waste_cost_yuan"] = row["waste_energy_kwh"] * price
            data["summary"]["waste_cost_yuan"] = data["summary"]["waste_energy_kwh"] * price
            for row in data["benefits"]:
                row["benefit_yuan"] = row["saving_kwh"] * price
                row["payback_years"] = data["parameters"]["investment_yuan"] / row["benefit_yuan"]
            output = root / "report.docx"
            with patch.object(build_report, "FIG_DIR", root / "figures"):
                build_report.build(self.write(root, data), output)
            doc = Document(output)
            prose = "\n".join(p.text for p in doc.paragraphs)
            cells = [cell.text for table in doc.tables for row in table.rows for cell in row.cells]
            self.assertIn("按 1.2 元每千瓦时", prose)
            self.assertIn("60.9", cells)
            self.assertIn("54.0 万至 78.0 万元", prose)
            self.assertNotIn("43.2 万元", prose)
            self.assertTrue((root / "figures" / "energy_baseline.png").is_file())


if __name__ == "__main__":
    unittest.main()
