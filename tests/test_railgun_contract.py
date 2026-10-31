"""Static contract checks for the visual-only scripted entity.

These do not replace tests in Garry's Mod. They prevent accidental changes to
sound coordination, default timing, and the visual-effects integration points.
"""
import pathlib
import hashlib
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

    def test_original_shaders_and_frame_records_preserved(self):
        hashes = {
            'shaders/src/ge_volume_ps30.fxc': 'dcd475dd9c2ba841a8ebbb0bf74bc6b52a9a8a7f7affd2ad5a20a65288ee1f36',
            'shaders/src/ge_volume_ps30.hlsl': 'b6d2c26dcbf6d4829aeeb2de50fa074e9b9000b8d060280e61c9fb1f209f4357',
            'shaders/src/ge_volume_vs30.fxc': 'd247ba386ce478f502b631895e61cb5b668b0101a86ede8d9400c7f5300aa31f',
            'shaders/src/ge_volume_vs30.hlsl': 'aecc83d6997d6b3cb73c61acbfb758ce8daed8ad1f35385c7bbde51ab04b2fa7',
            'lua/general_explosions/data/ground_explosion.lua': '8a54c09b37c37a231946eea66d89908a8624ae687ca37cafc35cec53f3f080cd',
        }
        for path, expected in hashes.items():
            data = (ROOT / path).read_bytes().replace(b'\r\n', b'\n')
            self.assertEqual(hashlib.sha256(data).hexdigest(), expected, path)


if __name__ == "__main__":
    unittest.main()
