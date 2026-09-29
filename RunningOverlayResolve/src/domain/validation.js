'use strict';

function invariant(condition, message) {
  if (!condition) {
    throw new TypeError(message);
  }
}

function isSafeInteger(value) {
  return Number.isSafeInteger(value);
}

function assertSafeInteger(value, name) {
  invariant(isSafeInteger(value), `${name} must be a safe integer`);
}

function assertFiniteNumber(value, name) {
  invariant(typeof value === 'number' && Number.isFinite(value), `${name} must be a finite number`);
}

function assertNonEmptyString(value, name) {
  invariant(typeof value === 'string' && value.trim().length > 0, `${name} must be a non-empty string`);
}

function assertRational(value, name) {
  invariant(value && typeof value === 'object', `${name} must be an object`);
  assertSafeInteger(value.numerator, `${name}.numerator`);
  assertSafeInteger(value.denominator, `${name}.denominator`);
  invariant(value.numerator > 0, `${name}.numerator must be positive`);
  invariant(value.denominator > 0, `${name}.denominator must be positive`);
}

function greatestCommonDivisor(a, b) {
  let left = Math.abs(a);
  let right = Math.abs(b);
  while (right !== 0) {
    const remainder = left % right;
    left = right;
    right = remainder;
  }
  return left || 1;
}

function reduceRational(numerator, denominator) {
  assertSafeInteger(numerator, 'numerator');
  assertSafeInteger(denominator, 'denominator');
  invariant(denominator !== 0, 'denominator must not be zero');

  const sign = denominator < 0 ? -1 : 1;
  const divisor = greatestCommonDivisor(numerator, denominator);
  return {
    numerator: sign * (numerator / divisor),
    denominator: Math.abs(denominator / divisor),
  };
}

function roundRationalProduct(value, rational) {
  assertSafeInteger(value, 'value');
  assertRational(rational, 'rational');
  const product = BigInt(value) * BigInt(rational.numerator);
  const denominator = BigInt(rational.denominator);
  const absoluteProduct = product < 0n ? -product : product;
  const roundedAbsolute = (absoluteProduct + denominator / 2n) / denominator;
  const rounded = product < 0n ? -roundedAbsolute : roundedAbsolute;
  const result = Number(rounded);
  invariant(Number.isSafeInteger(result), 'rounded rational result exceeds safe integer precision');
  return result;
}

module.exports = {
  assertFiniteNumber,
  assertNonEmptyString,
  assertRational,
  assertSafeInteger,
  greatestCommonDivisor,
  invariant,
  isSafeInteger,
  reduceRational,
  roundRationalProduct,
};
