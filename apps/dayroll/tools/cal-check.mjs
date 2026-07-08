import assert from 'node:assert'
const pad = (n) => (n < 10 ? `0${n}` : `${n}`)
// leadBlanks: 2026-07 (July 1 2026 = 周三, getDay()=3)
const firstDow = new Date(2026, 6, 1).getDay()
assert.equal(firstDow, 3, 'July 1 2026 应为周三')
assert.equal(new Date(2026, 6, 0 + 1).getDay(), 3)
assert.equal(firstDow, 3)                          // Sunday-start leadBlanks
assert.equal((firstDow + 6) % 7, 2)                // Monday-start leadBlanks
// daysInMonth / daysOf 借位
assert.equal(new Date(2026, 7, 0).getDate(), 31, 'July=31')
assert.equal(new Date(2025, 2, 0).getDate(), 28, 'Feb 2025=28')
assert.equal(new Date(2024, 2, 0).getDate(), 29, 'Feb 2024=29(闰)')
// isFuture: YYYY-MM-DD 字典序
const isFuture = (k, today) => k.localeCompare(today) > 0
assert.equal(isFuture('2026-07-09', '2026-07-08'), true)
assert.equal(isFuture('2026-07-08', '2026-07-08'), false)
assert.equal(isFuture('2026-07-07', '2026-07-08'), false)
// heatShade: 5 档，0=空
const ramp = ['#D8CCBA', '#B9A98C', '#8C7A5E', '#5E5039', '#232733']
const heatShade = (lvl) => lvl <= 0 ? '#EFE7D6' : ramp[Math.max(0, Math.min(4, lvl - 1))]
assert.equal(heatShade(0), '#EFE7D6')
assert.equal(heatShade(1), '#D8CCBA')
assert.equal(heatShade(5), '#232733')
assert.equal(heatShade(9), '#232733')              // 越界钳制
// moodScore: 索引 0(😄)=5 .. 4(😣)=1
const moods = ['😄','🙂','😐','😞','😣']
const moodScore = (m) => { const i = moods.indexOf(m); return i < 0 ? 0 : moods.length - i }
assert.equal(moodScore('😄'), 5)
assert.equal(moodScore('😣'), 1)
assert.equal(moodScore('x'), 0)
console.log('cal-check OK')
