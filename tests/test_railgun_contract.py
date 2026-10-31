"""Static contract checks for the visual-only scripted entity.

These do not replace tests in Garry's Mod. They prevent accidental changes to
sound coordination, default timing, and the visual-effects integration points.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENTITY = ROOT / "lua" / "entities" / "ge_orbital_railgun"


class RailgunVisualContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared = (ENTITY / "shared.lua").read_text(encoding="utf-8")
        cls.server = (ENTITY / "init.lua").read_text(encoding="utf-8")
        cls.client = (ENTITY / "cl_init.lua").read_text(encoding="utf-8")

    def test_fixed_sound_start_times(self):
        for marker in (
            "ENT.GEChargeAt = 0.0",
            "ENT.GEFireAt = 3.0",
            "ENT.GEImpactAt = 3.2",
        ):
            self.assertIn(marker, self.shared)
        for filename in (
            "railgun_charge.wav",
            "railgun_fire.wav",
            "railgun_explosion.wav",
        ):
            self.assertIn(filename, self.server)

    def test_effect_pipeline_hooks(self):
        self.assertIn("GEFXServer.Impact(", self.server)
        self.assertIn('concommand.Add("ge_railgun_fire"', self.server)
        self.assertIn("function ENT:SpawnFunction", self.server)
        self.assertIn("function ENT:DrawTranslucent()", self.client)
        self.assertIn("render.DrawBeam(", self.client)
        self.assertIn("render.DrawSprite(", self.client)
        self.assertIn("self:SetRenderBounds(", self.client)

    def test_only_cosmetic_actions(self):
        both = self.shared + self.server + self.client
        for forbidden in ("util.BlastDamage(", ":TakeDamage(", ":FireBullets("):
            self.assertNotIn(forbidden, both)


if __name__ == "__main__":
    unittest.main()
