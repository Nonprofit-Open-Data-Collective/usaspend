# Obligation trends, FY2026

How far below trend are FY2026 obligations to nonprofits? Federal grant
and contract obligations to matched nonprofits, October through May of
each fiscal year, against the trend set by FY2015–2019 and FY2022–2024.
The pandemic-relief years FY2020–21 are shown but not fitted.

Data through Same eight months every yearNominal dollarsDraft ·
preliminary

Measure

Net obligations

New awards

Dollars on new awards

A companion to [Nonprofit award disruption,
2025–26](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption-2025.md)
and [Disruption on the
ledger](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption-ledger.md).
Those follow the awards that were already running; this one asks how
much new money arrived. The series are built from the full nonprofit
database (all transactions to crosswalk UEIs since FY2008) and
pre-computed, since that database is not shipped with the package. The
measure switch above drives every chart on the page.

## The overall trend

Dots: actual October–May totals. Line: fitted trend, dashed where
projected. Shaded bands: 80% and 95% prediction intervals for FY2025 and
FY2026.

Fitted yearNot fitted (FY2020–21)Below the 95% bandTrend

## How far off, group by group

Group by

Funding agency

Program office

Recipient mission (NTEE)

Region

FY2026 actual relative to its own trend

0% = exactly on trend. Grey bars: the 80% (dark) and 95% (light)
prediction range for FY2026. Hollow ring: FY2025. Groups ordered by the
FY2026 gap; the figure at right is each group's average October–May
obligations in FY2022–24.

Trendlines by group

Same scale rules as the overall chart; each panel has its own y-axis.

## By state

FY2026 gap from trend, by recipient state

Color shows the percentage gap; states whose FY2026 value sits inside
their 80% prediction range are faded. Hover for values.

## How to read this

- **Window.** October 1 – May 31 of each fiscal year. The data run to 6
  September 2026 and Defense contract actions post up to 90 days late,
  so June–September 2026 is incomplete. The months chart below shows how
  much of a normal year the window covers.
- **Trend.** A straight line through the log of each series over
  FY2015–2019 and FY2022–2024 (a constant growth rate), fitted
  separately for every group. Series with a zero or negative year are
  fitted in levels. Eight points make wide intervals; a gap outside the
  95% band is a strong signal, one inside the 80% band is not.
- **New awards.** Awards whose first action ever (back to FY2008) falls
  in the window. Contracts under \$10,000 lifetime are left out of
  counts; they are mostly AbilityOne micro-orders. *Dollars on new
  awards* is what those awards were obligated in the same window.
- **Population.** Recipients are today’s nonprofits matched to
  USAspending, so earlier years miss organizations that have since
  closed. Part of the fitted growth is that composition effect, which
  makes the trend a little steep and the FY2026 gap a little large.
- **Agency** is the funding agency on each action (awarding agency where
  funding is blank); **program office** is the awarding sub-agency;
  **mission** is the recipient’s NTEE major group from the IRS Business
  Master File.

Share of each fiscal year's obligations by month

FY2023–FY2026. The October–May window holds roughly half a normal year;
September alone is often a fifth or more.

## Sources

USAspending annual award archives FY2008–FY2026 (generated 2026-09-06)
filtered to the npmatch nonprofit crosswalk. Grants (including
cooperative agreements) and contracts; loans, direct payments and IDV
vehicles excluded. Tables built by pipeline stage 30
(`30_obligation_trends.R` → `trends_tables.json`) on .
