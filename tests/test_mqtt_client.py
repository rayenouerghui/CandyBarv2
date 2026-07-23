import unittest

from PySide6.QtCore import QCoreApplication

from src.mqtt.client import MQTTClient


class MQTTClientStartupTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def test_starts_connected(self):
        client = MQTTClient()
        self.assertTrue(client.connected)
        self.assertEqual(client.status, "Connected")


if __name__ == "__main__":
    unittest.main()
