"""Focused contract tests; no runtime audit, Godot, HTTP or browser."""
import copy
import unittest
from contract import validate
from test_tools import TEMPLATE, ready_shape


class Protocol2ContractTests(unittest.TestCase):
    def test_numeric_protocol2_accepted_only_with_other_final_bindings(self):
        config = ready_shape()
        config['probe']['protocol'] = 2
        self.assertEqual(validate(config)['probe']['protocol'], 2)
        config['bindings']['ended'] = None
        with self.assertRaisesRegex(ValueError, 'authoritative end state'):
            validate(config)

    def test_unbound_template_still_rejects(self):
        config = copy.deepcopy(TEMPLATE)
        config['probe']['protocol'] = 2
        with self.assertRaisesRegex(ValueError, 'Waiting for coordinator'):
            validate(config)
        self.assertIsNone(TEMPLATE['probe']['protocol'])

    def test_protocol2_does_not_relax_input_or_performance_gates(self):
        for change, message in [
            (lambda c: c['probe'].update(protocol='2'), 'unsupported probe'),
            (lambda c: c['acceptance'].update(p95_target_ms=40), 'relax performance'),
            (lambda c: c['admission'].update(record_sha256=None), 'Unbound input'),
            (lambda c: c['runtime'].update(max_evidence_bytes=1024), 'byte budgets')]:
            config = ready_shape()
            config['probe']['protocol'] = 2
            change(config)
            with self.assertRaisesRegex(ValueError, message):
                validate(config)


if __name__ == '__main__':
    unittest.main(verbosity=2)
