const { test } = require('node:test');
const assert = require('node:assert/strict');
const { formatDate } = require('../src/formatDate');

test('formats a normal date in local time', () => {
  assert.equal(formatDate(new Date(2024, 10, 23)), '2024-11-23');
});

test('pads a single-digit month and day', () => {
  assert.equal(formatDate(new Date(2024, 0, 5)), '2024-01-05');
});

test('throws a TypeError for invalid input', () => {
  assert.throws(() => formatDate('2024-01-05'), TypeError);
  assert.throws(() => formatDate(new Date(Number.NaN)), TypeError);
});
