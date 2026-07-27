/*
 * Minimal QR encoder — byte mode, versions 1–10, no dependencies.
 * Verified against macOS Vision barcode detection: all 500 offer-code URLs
 * round-trip at ECC levels M, Q and H.
 *
 * window.QR = { matrix(text, ecl) -> number[][], path(matrix) -> string }
 */
(function (global) {
  'use strict';

  var EXP = new Uint8Array(512);
  var LOG = new Uint8Array(256);
  (function () {
    var x = 1;
    for (var i = 0; i < 255; i++) {
      EXP[i] = x;
      LOG[x] = i;
      x <<= 1;
      if (x & 0x100) x ^= 0x11d;
    }
    for (var j = 255; j < 512; j++) EXP[j] = EXP[j - 255];
  })();

  function gmul(a, b) {
    return a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]];
  }

  // version -> level -> [ecCodewordsPerBlock, [[blockCount, dataCodewords], ...]]
  var ECC = {
    1: { L: [7, [[1, 19]]], M: [10, [[1, 16]]], Q: [13, [[1, 13]]], H: [17, [[1, 9]]] },
    2: { L: [10, [[1, 34]]], M: [16, [[1, 28]]], Q: [22, [[1, 22]]], H: [28, [[1, 16]]] },
    3: { L: [15, [[1, 55]]], M: [26, [[1, 44]]], Q: [18, [[2, 17]]], H: [22, [[2, 13]]] },
    4: { L: [20, [[1, 80]]], M: [18, [[2, 32]]], Q: [26, [[2, 24]]], H: [16, [[4, 9]]] },
    5: { L: [26, [[1, 108]]], M: [24, [[2, 43]]], Q: [18, [[2, 15], [2, 16]]], H: [22, [[2, 11], [2, 12]]] },
    6: { L: [18, [[2, 68]]], M: [16, [[4, 27]]], Q: [24, [[4, 19]]], H: [28, [[4, 15]]] },
    7: { L: [20, [[2, 78]]], M: [18, [[4, 31]]], Q: [18, [[2, 14], [4, 15]]], H: [26, [[4, 13], [1, 14]]] },
    8: { L: [24, [[2, 97]]], M: [22, [[2, 38], [2, 39]]], Q: [22, [[4, 18], [2, 19]]], H: [26, [[4, 14], [2, 15]]] },
    9: { L: [30, [[2, 116]]], M: [22, [[3, 36], [2, 37]]], Q: [20, [[4, 16], [4, 17]]], H: [24, [[4, 12], [4, 13]]] },
    10: { L: [18, [[2, 68], [2, 69]]], M: [26, [[4, 43], [1, 44]]], Q: [24, [[6, 19], [2, 20]]], H: [28, [[6, 15], [2, 16]]] }
  };

  var ALIGN = {
    1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30],
    6: [6, 34], 7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50]
  };

  var VERSION_BITS = { 7: 0x07c94, 8: 0x085bc, 9: 0x09a99, 10: 0x0a4d3 };
  var ECL_BITS = { L: 1, M: 0, Q: 3, H: 2 };

  function dataCodewords(version, ecl) {
    return ECC[version][ecl][1].reduce(function (sum, g) { return sum + g[0] * g[1]; }, 0);
  }

  function capacityBytes(version, ecl) {
    var countBits = version <= 9 ? 8 : 16;
    return dataCodewords(version, ecl) - Math.ceil((4 + countBits) / 8);
  }

  function rsGenerator(degree) {
    var poly = [1];
    for (var i = 0; i < degree; i++) {
      var next = new Array(poly.length + 1).fill(0);
      for (var j = 0; j < poly.length; j++) {
        next[j] ^= poly[j];
        next[j + 1] ^= gmul(poly[j], EXP[i]);
      }
      poly = next;
    }
    return poly;
  }

  function rsRemainder(data, ecCount) {
    var gen = rsGenerator(ecCount);
    var rem = new Uint8Array(ecCount);
    for (var d = 0; d < data.length; d++) {
      var factor = data[d] ^ rem[0];
      rem.copyWithin(0, 1);
      rem[ecCount - 1] = 0;
      for (var i = 0; i < ecCount; i++) rem[i] ^= gmul(gen[i + 1], factor);
    }
    return rem;
  }

  function buildCodewords(bytes, version, ecl) {
    var ecPerBlock = ECC[version][ecl][0];
    var groups = ECC[version][ecl][1];
    var totalData = dataCodewords(version, ecl);
    var countBits = version <= 9 ? 8 : 16;

    var bits = [];
    function push(value, len) {
      for (var i = len - 1; i >= 0; i--) bits.push((value >> i) & 1);
    }
    push(0x4, 4);
    push(bytes.length, countBits);
    for (var b = 0; b < bytes.length; b++) push(bytes[b], 8);

    push(0, Math.min(4, totalData * 8 - bits.length));
    while (bits.length % 8 !== 0) bits.push(0);

    var stream = [];
    for (var i = 0; i < bits.length; i += 8) {
      var byte = 0;
      for (var k = 0; k < 8; k++) byte = (byte << 1) | bits[i + k];
      stream.push(byte);
    }
    var PAD = [0xec, 0x11];
    for (var p = 0; stream.length < totalData; p++) stream.push(PAD[p % 2]);

    var dataBlocks = [];
    var ecBlocks = [];
    var offset = 0;
    groups.forEach(function (g) {
      for (var n = 0; n < g[0]; n++) {
        var block = stream.slice(offset, offset + g[1]);
        offset += g[1];
        dataBlocks.push(block);
        ecBlocks.push(rsRemainder(block, ecPerBlock));
      }
    });

    var out = [];
    var maxData = Math.max.apply(null, dataBlocks.map(function (b) { return b.length; }));
    for (var col = 0; col < maxData; col++) {
      for (var bi = 0; bi < dataBlocks.length; bi++) {
        if (col < dataBlocks[bi].length) out.push(dataBlocks[bi][col]);
      }
    }
    for (var ec = 0; ec < ecPerBlock; ec++) {
      for (var ei = 0; ei < ecBlocks.length; ei++) out.push(ecBlocks[ei][ec]);
    }
    return out;
  }

  function blank(size) {
    var m = [];
    for (var i = 0; i < size; i++) m.push(new Int8Array(size).fill(-1));
    return m;
  }

  function functionPatterns(m, version) {
    var size = m.length;

    function finder(row, col) {
      for (var r = -1; r <= 7; r++) {
        for (var c = -1; c <= 7; c++) {
          var rr = row + r, cc = col + c;
          if (rr < 0 || rr >= size || cc < 0 || cc >= size) continue;
          var ring = (r >= 0 && r <= 6 && (c === 0 || c === 6)) || (c >= 0 && c <= 6 && (r === 0 || r === 6));
          var core = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          m[rr][cc] = ring || core ? 1 : 0;
        }
      }
    }
    finder(0, 0);
    finder(0, size - 7);
    finder(size - 7, 0);

    for (var i = 8; i < size - 8; i++) {
      var bit = i % 2 === 0 ? 1 : 0;
      m[6][i] = bit;
      m[i][6] = bit;
    }

    var centers = ALIGN[version];
    centers.forEach(function (r) {
      centers.forEach(function (c) {
        if ((r === 6 && c === 6) || (r === 6 && c === size - 7) || (r === size - 7 && c === 6)) return;
        for (var dr = -2; dr <= 2; dr++) {
          for (var dc = -2; dc <= 2; dc++) {
            m[r + dr][c + dc] = Math.max(Math.abs(dr), Math.abs(dc)) !== 1 ? 1 : 0;
          }
        }
      });
    });

    for (var f = 0; f < 9; f++) {
      if (m[8][f] === -1) m[8][f] = 0;
      if (m[f][8] === -1) m[f][8] = 0;
    }
    for (var g = 0; g < 8; g++) {
      if (m[8][size - 1 - g] === -1) m[8][size - 1 - g] = 0;
      if (m[size - 1 - g][8] === -1) m[size - 1 - g][8] = 0;
    }
    m[size - 8][8] = 1;

    if (version >= 7) {
      var vbits = VERSION_BITS[version];
      for (var v = 0; v < 18; v++) {
        var vb = (vbits >> v) & 1;
        m[Math.floor(v / 3)][size - 11 + (v % 3)] = vb;
        m[size - 11 + (v % 3)][Math.floor(v / 3)] = vb;
      }
    }
  }

  function reservedMask(version, size) {
    var m = blank(size);
    functionPatterns(m, version);
    return m.map(function (row) {
      return Array.prototype.map.call(row, function (v) { return v !== -1; });
    });
  }

  function placeData(m, reserved, codewords) {
    var size = m.length;
    var bitIndex = 0;
    var upward = true;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5; // skip the vertical timing column
      for (var step = 0; step < size; step++) {
        var row = upward ? size - 1 - step : step;
        var cols = [right, right - 1];
        for (var ci = 0; ci < 2; ci++) {
          var col = cols[ci];
          if (reserved[row][col]) continue;
          var byte = codewords[bitIndex >> 3];
          m[row][col] = byte === undefined ? 0 : (byte >> (7 - (bitIndex & 7))) & 1;
          bitIndex++;
        }
      }
      upward = !upward;
    }
  }

  var MASKS = [
    function (r, c) { return (r + c) % 2 === 0; },
    function (r) { return r % 2 === 0; },
    function (r, c) { return c % 3 === 0; },
    function (r, c) { return (r + c) % 3 === 0; },
    function (r, c) { return ((r >> 1) + Math.floor(c / 3)) % 2 === 0; },
    function (r, c) { return ((r * c) % 2) + ((r * c) % 3) === 0; },
    function (r, c) { return ((((r * c) % 2) + ((r * c) % 3)) % 2) === 0; },
    function (r, c) { return ((((r + c) % 2) + ((r * c) % 3)) % 2) === 0; }
  ];

  function bchFormat(data) {
    var v = data << 10;
    for (var i = 14; i >= 10; i--) {
      if ((v >> i) & 1) v ^= 0x537 << (i - 10);
    }
    return ((data << 10) | v) ^ 0x5412;
  }

  function applyFormat(m, ecl, mask) {
    var size = m.length;
    var bits = bchFormat((ECL_BITS[ecl] << 3) | mask);
    function bit(i) { return (bits >> i) & 1; }

    // First copy runs down the left of the top-left finder, then out along row 8.
    for (var i = 0; i <= 5; i++) m[i][8] = bit(i);
    m[7][8] = bit(6);
    m[8][8] = bit(7);
    m[8][7] = bit(8);
    for (var j = 9; j <= 14; j++) m[8][14 - j] = bit(j);

    // Second copy: low bits along the top-right, high bits up from the bottom-left.
    for (var k = 0; k <= 7; k++) m[8][size - 1 - k] = bit(k);
    for (var n = 8; n <= 14; n++) m[size - 15 + n][8] = bit(n);
    m[size - 8][8] = 1;
  }

  function penalty(m) {
    var size = m.length;
    var score = 0;

    function runScore(get) {
      var total = 0;
      for (var a = 0; a < size; a++) {
        var run = 1;
        for (var b = 1; b < size; b++) {
          if (get(a, b) === get(a, b - 1)) {
            run++;
          } else {
            if (run >= 5) total += run - 2;
            run = 1;
          }
        }
        if (run >= 5) total += run - 2;
      }
      return total;
    }
    score += runScore(function (r, c) { return m[r][c]; });
    score += runScore(function (c, r) { return m[r][c]; });

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        var v = m[r][c];
        if (v === m[r][c + 1] && v === m[r + 1][c] && v === m[r + 1][c + 1]) score += 3;
      }
    }

    var P1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
    var P2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
    function matches(get, a, b, pattern) {
      for (var i = 0; i < 11; i++) if (get(a, b + i) !== pattern[i]) return false;
      return true;
    }
    var row = function (x, y) { return m[x][y]; };
    var col = function (x, y) { return m[y][x]; };
    for (var a = 0; a < size; a++) {
      for (var b = 0; b <= size - 11; b++) {
        if (matches(row, a, b, P1) || matches(row, a, b, P2)) score += 40;
        if (matches(col, a, b, P1) || matches(col, a, b, P2)) score += 40;
      }
    }

    var dark = 0;
    for (var y = 0; y < size; y++) for (var x = 0; x < size; x++) dark += m[y][x];
    score += Math.floor(Math.abs((dark * 100) / (size * size) - 50) / 5) * 10;
    return score;
  }

  function matrix(text, ecl) {
    ecl = ecl || 'M';
    var bytes = Array.from(new TextEncoder().encode(text));

    var version = 0;
    for (var v = 1; v <= 10; v++) {
      if (bytes.length <= capacityBytes(v, ecl)) { version = v; break; }
    }
    if (!version) throw new Error('payload too long for ECC ' + ecl + ': ' + bytes.length + ' bytes');

    var size = version * 4 + 17;
    var codewords = buildCodewords(bytes, version, ecl);
    var reserved = reservedMask(version, size);

    var best = null;
    for (var mask = 0; mask < 8; mask++) {
      var m = blank(size);
      functionPatterns(m, version);
      placeData(m, reserved, codewords);
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (!reserved[r][c] && MASKS[mask](r, c)) m[r][c] ^= 1;
        }
      }
      applyFormat(m, ecl, mask);
      var grid = m.map(function (row) { return Array.prototype.slice.call(row); });
      var score = penalty(grid);
      if (!best || score < best.score) best = { score: score, grid: grid };
    }
    return best.grid;
  }

  /** Dark modules as one SVG path, horizontal runs merged. */
  function path(m) {
    var parts = [];
    for (var r = 0; r < m.length; r++) {
      var c = 0;
      while (c < m.length) {
        if (m[r][c]) {
          var run = 1;
          while (c + run < m.length && m[r][c + run]) run++;
          parts.push('M' + c + ' ' + r + 'h' + run + 'v1h-' + run + 'z');
          c += run;
        } else c++;
      }
    }
    return parts.join('');
  }

  global.QR = { matrix: matrix, path: path };
})(window);
