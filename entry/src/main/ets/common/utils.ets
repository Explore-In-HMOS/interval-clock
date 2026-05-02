function simpleHash(n: number): string {
  return (n ^ (n << 5) ^ (n >> 7)).toString(16);
}

export function generateRandomToken(prefix: string) {
  const now = Date.now();
  return `${prefix}-${now}-${simpleHash(now)}`;
}