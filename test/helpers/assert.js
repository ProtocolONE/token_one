const around = (a, b, diff) => {
  const abs = Math.abs(a - b);
  if (abs > diff) {
    throw new Error(`Assertion failed: ${a} is not ${diff} around ${b}`);
  }
};

export default { around };
