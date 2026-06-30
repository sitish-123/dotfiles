pragma Singleton
import Quickshell

// ponytail: lookup table 2070-2090 BS (~2013-2033 AD). Extend _data when needed.
Singleton {
    id: root

    readonly property var _data: ({
        2070: [31,32,31,32,31,30,30,29,30,29,30,30],
        2071: [31,31,32,31,31,31,30,29,30,29,30,30],
        2072: [31,31,32,32,31,30,30,29,30,29,30,30],
        2073: [31,32,31,32,31,30,30,30,29,29,30,31],
        2074: [30,32,31,32,31,30,30,30,29,29,30,30],
        2075: [31,31,32,31,31,31,30,29,30,29,30,30],
        2076: [31,31,32,32,31,30,30,29,30,29,30,30],
        2077: [31,32,31,32,31,30,30,30,29,29,30,30],
        2078: [31,31,31,32,31,31,29,30,30,29,29,31],
        2079: [31,31,32,31,31,31,30,29,30,29,30,30],
        2080: [31,31,32,32,31,30,30,29,30,29,30,30],
        2081: [31,32,31,32,31,30,30,30,29,29,30,30],
        2082: [31,31,31,32,31,31,29,30,30,29,30,30],
        2083: [31,31,32,31,31,31,30,29,30,29,30,30],
        2084: [31,31,32,32,31,30,30,29,30,29,30,30],
        2085: [31,32,31,32,31,30,30,30,29,29,30,30],
        2086: [31,31,31,32,32,30,30,29,30,29,30,30],
        2087: [31,32,31,32,31,30,30,30,29,29,30,30],
        2088: [30,32,31,32,31,31,29,30,30,29,30,30],
        2089: [31,31,32,31,31,31,30,29,30,29,30,30],
        2090: [31,31,32,32,31,30,30,29,30,29,30,30],
    })

    readonly property var monthNamesRoman: [
        "Baisakh","Jestha","Ashadh","Shrawan",
        "Bhadra","Ashwin","Kartik","Mansir",
        "Poush","Magh","Falgun","Chaitra"
    ]
    readonly property var monthNamesDevanagari: [
        "बैशाख","जेष्ठ","आषाढ","श्रावण",
        "भाद्र","आश्विन","कार्तिक","मंसिर",
        "पुष्य","माघ","फाल्गुन","चैत्र"
    ]

    // Fixed BS-calendar public holidays (solar-fixed only; lunar festivals shift annually)
    // ponytail: only include dates that are truly fixed in BS calendar
    readonly property var _holidays: [
        { month: 1,  day: 1,  name: "Nepali New Year (Navabarsha)" },
        { month: 2,  day: 15, name: "Republic Day (Ganatantra Diwas)" },
        { month: 6,  day: 3,  name: "Constitution Day" },
        { month: 9,  day: 27, name: "Prithvi Jayanti" },
        { month: 10, day: 1,  name: "Maghe Sankranti" },
        { month: 11, day: 7,  name: "Democracy Day (Prajatantra Diwas)" },
    ]

    // Reference: April 13, 2024 AD = Baisakh 1, 2081 BS
    readonly property int _rY:  2024
    readonly property int _rM:  3     // 0-indexed (April)
    readonly property int _rD:  13
    readonly property int _rBY: 2081
    readonly property int _rBM: 1
    readonly property int _rBD: 1

    function toBS(adDate) {
        const ref = new Date(_rY, _rM, _rD)
        let rem = Math.round((adDate - ref) / 86400000)
        let y = _rBY, m = _rBM, d = _rBD
        if (rem >= 0) {
            while (rem > 0) {
                const md = _data[y]; if (!md) break
                const left = md[m - 1] - d
                if (rem <= left) { d += rem; rem = 0 }
                else { rem -= left + 1; d = 1; if (++m > 12) { m = 1; y++ } }
            }
        } else {
            rem = -rem
            while (rem > 0) {
                if (rem < d) { d -= rem; rem = 0 }
                else { rem -= d; if (--m < 1) { m = 12; y-- }; const md = _data[y]; if (!md) break; d = md[m - 1] }
            }
        }
        return { year: y, month: m, day: d }
    }

    function _toNumerals(n) {
        return String(n).split("").map(c => "०१२३४५६७८९"[parseInt(c)] ?? c).join("")
    }

    function formatBS(bs, fmt) {
        const mn = monthNamesRoman[bs.month - 1]
        switch (fmt) {
            case "dayMonth":   return mn + " " + bs.day
            case "monthName":  return mn + " " + bs.day + ", " + bs.year
            case "short":      return bs.day + "/" + bs.month + "/" + bs.year
            case "devanagari": return monthNamesDevanagari[bs.month - 1] + " " + bs.day + ", " + bs.year
            case "numerals":   return monthNamesDevanagari[bs.month - 1] + " " + _toNumerals(bs.day) + ", " + _toNumerals(bs.year)
            default:           return bs.day + "/" + bs.month + "/" + bs.year
        }
    }

    // Returns holiday name string if bs date is a fixed holiday, otherwise null
    function getHoliday(bs) {
        for (let i = 0; i < _holidays.length; i++) {
            const h = _holidays[i]
            if (h.month === bs.month && h.day === bs.day) return h.name
        }
        return null
    }

    // Returns "Ashadh 2083" style string for a given AD date
    function yearMonthBS(adDate) {
        const bs = toBS(adDate)
        return monthNamesRoman[bs.month - 1] + " " + bs.year
    }
}
