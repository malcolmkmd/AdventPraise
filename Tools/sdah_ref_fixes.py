"""Corrections to the Christ In Song -> SDA Hymnal (1985) cross-references.

The "(Vern-n, AH-n, SDAH-n)" subtitles behind refs.sdah in english.json have
slips: some point at the neighbouring hymn, a few pairs are swapped, and some
name an SDAH hymn although the song isn't in the 1985 hymnal at all. Each
number here was checked against hymnary.org (https://hymnary.org/hymn/SDAH1985/n)
by title, first line and tune. None means there is no SDAH 1985 equivalent, so
the reference is dropped.

convert_hymnals.py applies these to english.json; build_collections.py uses them
in place of the subtitle and Tonga/Sepedi references.
"""

CIS_TO_SDAH = {
    23: 260,    # Hover O'er Me, Holy Spirit (was 263, Fire of God, Thou Sacred Flame)
    59: 489,    # Jesus, Lover of My Soul (was 229, All Hail the Power); SDAH sets it to MARTYN (489) and HOLLINGSIDE (490), CIS sings ABERYSTWYTH
    71: None,   # Is My Name Written There? is not in SDAH 1985 (was 368, Watchman, Blow the Gospel Trumpet)
    79: 358,    # Far and Near the Fields Are Teeming (was 359, Hark! the Voice of Jesus Calling)
    106: 531,   # We'll Build on the Rock (was 342, Is This a Day of New Beginnings?)
    115: 254,   # The Great Physician Now Is Near (was 252, Come, Let Us Sing)
    119: 332,   # The Cleansing Wave (was 184, Jesus Paid It All)
    120: 486,   # I Do Believe / Father, I stretch my hands to Thee (was 332, The Cleansing Wave); SDAH tune I DO BELIEVE, CIS sings NAOMI
    121: 183,   # I Will Sing of Jesus' Love (was 486, I Do Believe)
    151: None,  # Will There Be Any Stars? is not in SDAH 1985 (was 366, O Where Are the Reapers?)
    173: 440,   # How Cheering Is the Christian's Hope (was 533, O for a Faith)
    174: 533,   # O for a Faith That Will Not Shrink (was 440); SDAH tune NORTHFIELD, CIS sings ST. AGNES
    241: None,  # Beulah Land is not in SDAH 1985 (was 368, Watchman, Blow the Gospel Trumpet)
    269: 520,   # A Wonderful Savior / He Hideth My Soul (was 102, Unto the Hills)
    284: None,  # While the Days Are Going By is not in SDAH 1985 (was 554, O Let Me Walk With Thee)
}


def apply(refs, number):
    """refs dict for CIS hymn `number`, with the SDAH reference corrected."""
    if number not in CIS_TO_SDAH:
        return refs
    out = {k: v for k, v in refs.items() if k != "sdah"}
    if CIS_TO_SDAH[number] is not None:
        out["sdah"] = CIS_TO_SDAH[number]
    return out
