# Phantom 付费逻辑与切入点复盘（2026-09-10）

方法：Sonnet 5 四路并行调研（A 竞品付费 / B 痛点与监管 / C App Store 赛道与转化基准 / D 抽成模式战绩），Fable 5.1 归纳。所有数字附来源，原始调研在附录 A–D；未能核实的项在附录中标 unverified。

## 1. 现状（代码与 App Store 页面事实）

- App Store：「Phantom: Subscription Killer」，副标题「Find Hidden Subscriptions」，v1.2（2026-08-21），1 条评分，Finance 类。
- 定价：Pro $3.99/月、$29.99/年，无试用。Paywall 有「Refund within 30 days」徽章（IAP 退款由 Apple 决定，开发者无法承诺）。
- 实际付费闸门（代码）：Radar 只显示按金额排序的前 5 个订阅；Alerts 只显示 1 条；申诉信每月 1 封；谈判话术全锁。取消清单、证据库、chargeback 脚本、僵尸分及拆解全部免费。`Entitlements.isProGated` 无任何调用（死代码）。
- 宣传与闸门不一致：Paywall perks 与商店描述都把「Cancel checklists」「evidence locker」「Zombie Score」列为 Pro 权益。
- 申诉信把「FTC Negative Option Rule (16 C.F.R. § 425)」列为违规依据；该规则 2025-07-08 被第八巡回法院整体撤销（附录 B）。
- 申诉流程不区分 Apple 代扣：Apple 代扣的订阅也生成给商家的信，而商家无法退 Apple 代收的款。
- 无漏斗数据（无 analytics SDK，是隐私承诺的一部分）。价格目录 56 个服务（PRD 写 2,000+）。取消注册表 58 家，谈判话术 47 家。

## 2. 赛道的付费逻辑（实证）

| 原型 | 代表与价格 | 付费点 | 来源 |
|---|---|---|---|
| A. 理财套件 | Copilot $95/yr、Monarch $99.99/yr、YNAB $109/yr、PocketGuard $74.99/yr（lifetime $149.99） | 整个理财 OS；试用后硬付费墙；必须连银行（YNAB 除外） | 附录 A |
| B. 独立追踪器 | Bobby $2.99 一次性（4.7★/8K）、Subby 免费无限 + 一次性 PRO、SubManager 免费无限、Vault $7.99/yr 或 $14.99 永久、ReSubs、TrackMySubs $99/yr | 追踪基本免费或 $2–15 一次性；「不连银行 / 截图导入」是该阵营标配（Vault、ReSubs、FYM、Subkeep） | 附录 A、C |
| C. 代办服务 | Rocket Money Premium $7–14/mo + 谈判抽成 35–60%（4.5★/389K）；Experian $24.99/mo 打包 200+ 商家取消 + 谈判；Pine AI $29/mo；SubPilot 按次 $4.99–17.99、Concierge $49.99–59.99（4.5★/4.7K）；DoNotPay ~$36/3 月；Billshark 40% + $9/次取消 | 「替你取消 / 谈判」 | 附录 A、C、D |
| 免费层 | Capital One（免费查看 + 拦截扣款）、U.S. Bank + Mastercard（2025-10-15 免费）、Visa 发卡行基础设施（2026 夏起）、Apple Card iOS 27「Recurring」、iOS 26.5 试用到期角标 | 「发现订阅」正在被银行卡层免费化；Mastercard 调研 72% 用户希望在银行 app 内看到 | 附录 A |

四个结论：

1. 「找出订阅」不值钱了：独立追踪器免费送，银行卡层也在免费送。Phantom 现在恰恰把付费墙砌在这一层（第 6 个订阅起收费）。
2. 「替你办」值钱（$7–29/mo 或 35–60% 抽成），但需要后端、人力或代理，且独立玩家在整合或死亡（Trim→OneMain 客户专属、Cushion 倒闭、ScribeUp 转 B2B 授权给信用社）。
3. 独立阵营的价格锚是「一次性 $2–15」；订阅制的纯追踪器在这一层没有成功先例。
4. 抽成模式：独立抽成公司要么被收购后免费化（Paribus、Harvest、Trim），要么死（Earny、Cushion）；活下来的（AirHelp 35%）是自己干活并能看到回款。Phantom 看不到退款（无银行数据），也不能通过 IAP 收抽成（Apple 3.1.3(e) 要求现实世界服务走卡外收款）。PRD 的「15% 退款分成」不可行。

## 3. Phantom 还能做什么，解决什么痛点

空位在「我们找到了」（到处免费）与「我们替你办」（$7–29/mo）之间：**确保取消生效、留证、把钱要回来**。证据：

- 痛点真实且是投诉榜首：「已取消仍扣款」（Chegg 约 20 万人取消后仍被扣，FTC $7.5M，2025-09；Rocket Money 2026-04 / 2026-08 投诉原文）；「试用忘记取消被扣」（近半数用户，GCN 2026）；「涨价」（90% 注意到涨价、22% 因此取消，Chargebee 2025-09-23）。
- 钱要得回来：50% 持卡人争议过扣款，最近一次 96% 成功，21% 的争议针对订阅（LendingTree）；平均争议金额 $94（Chargebacks911 2026）。
- 法律杠杆在州层面加强：CA AB 2863（2025-07-01）点击取消 + 涨价明示通知；NY（2025-11-05）涨价须明示同意，否则 14 天无罚取消并按比例退款；MN（2025-01-01）。联邦规则撤销后 FTC 仍以 ROSCA 执法（Amazon $2.5B，2025-09-25；Match $14M；Care.com $8.5M；Cleo $17M）。
- 独立阵营没人卖这个；DoNotPay 卖但带 FTC 处罚记录（$193K，2025-01）；Recoup 抽 25% 且有免费 DIY 层。
- 按次付费在本赛道被接受：SubPilot 按次 $4.99–17.99；Billshark $9/次取消。
- 付费时机：在「价值时刻」出付费墙，试用开启率 65% vs 开屏硬墙 31%（Adapty 2026，二手汇总）。

结构性优势：零边际成本。Cushion 有 20 万付费用户、$15M 退款仍因「规模不够」倒闭；Phantom 无后端，在类目中位数（$492/月，RevenueCat 2026）也能活。

## 4. 现在的 app 怎么改（按优先级）

**P0 切入点与商店定位**

- 意图从「找隐藏订阅」（拥挤、免费）转到「被错扣了钱 → 取消、留证、要回」。副标题改「Cancel. Prove it. Get refunds.」（30 字符）；关键词去掉 plaid / bank / budget，换 refund, dispute, chargeback, charged, trial, price increase, proof。参照 SubPilot：副标题「Find & stop unwanted charges」，2025 年上线，一年 4.7K 评分（评分数不等于收入，但说明意图有流量）。
- 首屏改问「发生了什么？」：已取消仍扣款 / 试用转付费 / 涨价 / 只是想清理。前三条直达申诉流程；第四条走免费审计。
- Apple 代扣的订阅：申诉直接跳 Apple 退款流程（reportaproblem.apple.com），不发商家信。

**P0 付费闸门对齐**

- 免费：全部订阅 + 僵尸分 + 取消清单（与 Capital One / Bobby / Subby 免费层持平）。当前「按金额取前 5」隐藏的恰恰是便宜的僵尸订阅：Self 2026 平均 2.6 个未用订阅、平均损失 $34。
- 「Clawback Kit」消耗型 IAP $4.99–6.99 / 一笔扣款：申诉信 + chargeback 包 + 证据库 + 14 天跟进。价格锚：平均争议 $94，约 5–7%（Recoup 25%、Rocket 35–60%）。生成的信件是 app 内数字内容，走 IAP 合规。
- Pro $29.99/年（类目中位数 $34.80–38.42），加 14 天试用（17–32 天试用转化 42.5%；含试用在几乎所有测试中胜出，Superwall 2026）；加 Lifetime ~$59.99（年费 2 倍；类目 2.1–11.5×；「订阅 + 永久」是第二常见形态）。月付 $3.99 建议去掉（月付 D380 留存 14.2% vs 年付 19.9%；年付首年取消率已达 72%）。
- 去掉「Refund within 30 days」徽章。

**P1 法律精度**

- 申诉信删除「Negative Option Rule 16 C.F.R. § 425 违规」，改为 ROSCA 15 U.S.C. § 8403 + 州自动续费法（CA §17602 经 AB 2863；NY GBL §527-a 2025-11）。新增「涨价未同意 → 14 天按比例退款（NY）」信种，并与涨价提醒联动。
- Chargeback 包：Reg E 只覆盖借记 / EFT 未授权转账；信用卡走 Reg Z §1666；「已取消仍扣」优先用卡组织理由码（Visa 13.2 / Mastercard 4853 Cancelled Recurring）。此段建议法律核对。

**P1 文案合规**

- 「$47/月平均省」（商店截图文案）无数据支撑；DoNotPay 因无依据的效果宣称被 FTC 罚 $193K。改用带出处的人群统计（C+R 2022 低估 $133/月；Self 2026 平均 2.6 个未用订阅）。
- Paywall / 商店的 Pro 权益列表与实际闸门对齐。

**P2 度量**

- 不加 SDK 也能测：App Store Connect 曝光 → 页面 → 安装转化率、StoreKit 订阅事件、Apple opt-in 留存。先测 P0 的副标题 / 关键词变化。

## 5. 不做

- 15% 退款抽成（无法计量、需卡外收款、独立先例全灭）。
- 自建 concierge / 代理取消（后端 + 人力，独立玩家在死）。
- 更多「识别」功能（银行卡层正在免费化）。
- 连银行（EPIC 对 Rocket Money 的 CFPB 投诉证明这是反向卖点）；但「不连银行」在独立阵营已是标配，不能作为唯一卖点。

---


## 附录 A — competitor monetization

# A — Competitor monetization (Sonnet 5, 2026-09-10)

## Bill negotiation / cancellation services
| Product | Pricing model | Bank link? | Paywall placement | Rating | Source |
|---|---|---|---|---|---|
| Rocket Money | Free tier (see subs, 2 budget categories) + Premium pay-what-you-want $7–$14/mo (was ~$6–$12 early 2025; new Premium+ $15/mo in 2026). Bill negotiation billed separately, 35–60% of first-year savings, available without Premium. | Yes (Plaid) | Tracking free; cancel-concierge + budgets behind Premium; negotiation fee on success | 4.5★/389K | rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost (2026); apps.apple.com/us/app/rocket-money-bills-budgets/id1130616675 (2026-09-10) |
| Trim (OneMain) | Consumer app wound down ~2022; negotiation now free but only for OneMain loan customers | N/A | N/A | — | financebuzz.com/save-money-with-trim (2026); trimhelp.zendesk.com |
| Billshark | 40% of savings (capped ~24 mo), + $9 per subscription cancellation | No | Success fee | — | billshark.com/blogs/bill-negotiation-fees-are-they-worth-it; thecollegeinvestor.com/32389/billshark-review (2026) |
| BillCutterz | 50% of ongoing savings or 40% flat | No | Success fee | — | moneycrashers.com/best-bill-negotiation-services (2026) |
| Experian BillFixer | Negotiation + subscription cancellation (200+ merchants) bundled in $24.99/mo Premium ($34.99 Family); user keeps 100% of savings | Not for negotiation | Paid member only (7-day trial) | — | experian.com/blogs/ask-experian/what-is-experian-billfixer (2026-09-10); security.org (2026) |
| DoNotPay | ~$36/3 mo ($35.99 on App Store); no free tier | No | Immediate | 4.3★/7.6K | apps.apple.com/us/app/donotpay/id1427999657 (2026-09-10) |

DoNotPay FTC: order finalized 2025-01-16, $193,000 relief + bar on unsubstantiated "AI lawyer" claims; still operating mid-2026. ftc.gov/news-events/news/press-releases/2025/02/ftc-finalizes-order-donotpay-...
Cushion: shut down end of 2024; 200,000+ paying users, >$15M refunds secured, "inability to reach sustaining scale". techcrunch.com/2025/01/30/fintech-startup-cushion-shuts-down-after-8-years-and-over-20-million-in-funding

## Indie trackers
| Bobby | Free 5 subs; one-time $2.99 "All-in-one Pack v2" | manual | after 5th sub | 4.7★/8K+ | apps.apple.com/.../id1059152023 (2026-09-10) |
| Subby | Free unlimited (ads); PRO one-time lifetime (ads off, backup, widgets, AI scan) | no | upsell only | — | subby.io; subby.online/pro.html (2026) |
| TrackMySubs | Free 10 subs; $10/mo or $99.99/yr | manual/CSV | after 10 | web | trackmysubs.com/pricing (2026) |
| SubManager | Free unlimited tracking + reminders; one-time "+" for price history | on-device | cosmetic | — | apps.apple.com/.../id6757600942; submanager.app (2026) |

## Budgeting suites
Copilot $13/mo or $95/yr, no free tier, 30-day trial w/ card, 4.8★/~24K (getfinny.app 2026). Monarch $99.99/yr Core, $199/yr Plus, 7-day trial, 4.9★/70K (getfinny.app; cnbc.com 2026). YNAB $14.99/mo or $109/yr, 34-day trial, manual-entry mode optional, 4.8★/50K+ (intuit.com blog 2026-03-16). PocketGuard Plus $12.99/mo or $74.99/yr, lifetime $149.99 (getfinny.app 2026). Cleo Plus $5.99, Pro $8.99 (Apr 2026), Builder $14.99 (fincomparelab.com 2026). ScribeUp pivoted to B2B credit-union licensing (Service CU Jan 2025; Advia CU 2026-02-26). Emma UK £4.99–£14.99/mo (help.emma-app.com 2026).

## Bank/network-native (free)
- Capital One: free, in-app auto-detect subs + block/unblock future charges. capitalone.com/digital/tools/subscription-management (2025–26)
- U.S. Bank + Mastercard: free, launched 2025-10-15, view subs + itemized receipts; Mastercard survey: 72% of consumers want this inside banking app. businesswire.com/news/home/20251015020220/en/
- Visa "Enhanced Subscription Manager" (with Pinwheel): issuer infrastructure to view/manage/switch/cancel, rolling to North American issuers summer 2026. businesswire.com/news/home/20260326149948/en/ (2026-03-26)
- Apple Card, iOS 27 (announced ~Jun 2026): "Recurring" section — predicted recurring charges, list/calendar; Apple Card only. 9to5mac.com/2026/07/22/apple-card-adds-new-feature-in-ios-27...
- iOS 26.5 (2026-03-30): trial-ending badges + 12-month commitment plan type in Settings→Subscriptions (App Store IAP only). 9to5mac.com/2026/03/30/...
- Chase: no dedicated product; points to alerts + manual review; suggests third-party apps. chase.com/.../subscription-fatigue (2026-09-10)
- Amex: unverified / none found.

## Patterns
- Free across category: detection/tracking (indie trackers give unlimited free; banks/networks fold it into card apps).
- Consistently paid: cancel-concierge, negotiation, full budgeting suites.
- Success-fee negotiators: 35–60% of first-year savings (Rocket 35–60, Billshark 40+$9, BillCutterz 40–50); Experian outlier = flat membership, user keeps 100%.
- Indie price poles: $1.99–$2.99 one-time unlock vs $95–$109/yr suites; little in the middle.
- Bank-linking is the norm for suites; indie trackers sell "no bank login".
- 2025–26: standalone negotiation/clawback apps consolidating or dying (Trim, Cushion, ScribeUp→B2B); paywall moving to card/bank layer; incumbents raising prices (Rocket $6→$7 floor + $15 Premium+; Cleo new $8.99 tier).

## 附录 B — pain points regulation

# B — Consumer pain, regulation, tool complaints (Sonnet 5, 2026-09-10)

## Part 1 — Quantified pain
- C+R Research (2022, still the cited benchmark): guessed $86/mo vs actual $219; 74% say recurring charges easy to forget; 42% forgot they were paying for an unused sub. crresearch.com/blog/subscription-service-statistics-and-costs
- Self Financial "Cost of Unused Paid Subscriptions 2026": 59.9% have ≥1 unused sub in a typical month, avg 2.6 unused; forgetting to cancel cost $34.31 on average. self.inc/info/cost-of-unused-paid-subscriptions
- GCN 2026: unused app subscriptions cost Americans ~$15.5B/yr; "nearly half" charged after forgetting to cancel a free trial. gcn.com/unused-app-subscriptions-15-billion-drain/21479
- Chargebee 2025 Global Consumer Insights (1,454 US/UK, 2025-09-23): 90% noticed a price increase in past year; 58% felt justified; 22% cancelled after a hike; 14% downgraded. businesswire.com/news/home/20250923678021/en
- ConsumerAffairs Jan 2026: subscription price creep "quietly got worse in late 2025".
- LendingTree dispute study (~2,000 US adults, ~2024–25): 50% of cardholders have disputed a charge; 96% of most-recent disputes resolved successfully; 21% of disputes challenged a subscription charge. lendingtree.com/credit-cards/study/disputes
- Moneywise 2025/26: 158M transaction disputes filed in 2025.
- Juniper Research 2026: friendly fraud ~22% of chargebacks (→28% by 2031).
- Chargebacks911 2026 Field Report: avg disputed transaction $94; >25% of recurring-billing merchants send no pre/post-charge reminder. chargebacks911.com/chargeback-field-report
- Not found: reliable "average time to cancel" stat.

## Part 2 — Regulation as of Sept 2026
- FTC Negative Option ("click-to-cancel") Rule: finalized Oct 2024; vacated in full by 8th Circuit 2025-07-08 (APA grounds). sidley.com (Jul 2025); wilmerhale.com (2025-08-01): FTC keeps enforcing via FTC Act §5 + ROSCA + state UDAP.
- Restart: draft ANPRM to OIRA 2026-01-30 (Sidley Feb 2026); ANPRM issued early Mar 2026; comments closed 2026-04-13 (~100 comments); rule NOT in effect, no NPRM yet. jonesday.com (May 2026)
- Enforcement: Amazon Prime $2.5B (2025-09-25; $1B penalty + $1.5B restitution, ~35M consumers). Chegg $7.5M (Sept 2025; ~200K charged after cancel request). Match $14M (Sept 2025; barred from retaliating against dispute filers). Care.com $8.5M (2025-06-25). Cleo AI $17M (2025-03-27, cancellation obstruction). Uber One sued Apr 2025 (up to 23 screens/32 actions to cancel), 21 states joined Dec 2025. LA Fitness + Adobe still in litigation.
- State law: CA AB 2863 eff. 2025-07-01 (same-medium cancel, click-to-cancel, annual reminders, clear notice of price changes, covers trials). MN eff. 2025-01-01 (cancel button, annual reminder, ban on unsolicited save offers). NY eff. 2025-11-05 (price increase needs affirmative consent OR 14-day penalty-free cancel + pro-rated refund; notice before first charge on trials >1 month). NYC municipal click-to-cancel proposed Jun 2026. kelleydrye.com "Auto-Renewal Laws: 2025 Round Up"; ktslaw.com; dwt.com
- CFPB: enforcement/supervision/staff cut Feb–Aug 2025 (GAO via consumerfinancialserviceslawmonitor.com Feb 2026); Reg E dispute mechanics (written notice, provisional credit, timelines) not rescinded.
- Apple: price increases above thresholds (~$5 & 50% monthly; ~$50 & 50% annual) require explicit opt-in; non-consent auto-lapses. developer.apple.com/help/app-store-connect/reference/auto-renewable-subscription-price-increase-thresholds; support.apple.com/en-us/109501
- Google Play: requires easy online cancel in-app and on website. support.google.com/googleplay/android-developer/answer/9900533

## Part 3 — Verbatim complaints (Rocket Money unless noted)
1. "I was unaware that auto negotiation was turned on. I did not turn it on, it was turned on by default." BBB 2026-07-09. bbb.org/us/md/silver-spring/profile/billing-services/rocket-money-inc-0241-236043013/complaints
2. "I canceled my subscription immediately on the same day I was charged and deleted my account right away. Despite that, the company still proceeded with this charge." BBB 2026-04-08.
3. "Rocket money reached out to Xfinity and negotiated my Xfinity account without my authorization." BBB 2026-03-26.
4. "they didn't save me anything, my Sirius bill actually went up from $6.99 monthly to $27.99 monthly" Trustpilot 1★ 2026-09-01. trustpilot.com/review/rocketmoney.com
5. "He canceled the subscription about 2023. At this point has been charged approximately $300." Trustpilot 2026-08-23.
6. "once I canceled, I had to download my transactions. But they didn't let me because I wasn't a premium subscriber." Trustpilot 2026-08-28.
7. "The bill negotiation option, unfortunately didn't work and wasn't able to connect with any of my accounts." App Store review Jun 23.
8. "I subscribed to this product because I wanted my subscriptions handled. I have no idea how to do that on here." App Store review Mar 15. (identified-but-didn't-act)
9. "they don't let you cancel; they just steal your money every month." PissedConsumer 2026-08-10.
10. "It should not be so hard for a person to cancel their subscription if they lose access to an old email, an old phone number, or both." PissedConsumer 2026-07-19.
11. EPIC + NYU CFPB complaint (Dec 2022): Rocket Money "forces users to link their bank accounts with Plaid". epic.org/documents/epic-cfpb-complaint-rocket-money
12. Rocket Money Help Center: "if you don't see a Cancel option, Rocket Money is not yet able to cancel that particular subscription on your behalf." help.rocketmoney.com/en/articles/934402
- Manual-entry fatigue / alert fatigue: only secondary blog aggregations (vento.money), low confidence.

## 附录 C — appstore benchmarks

# C — App Store landscape + monetization benchmarks (Sonnet 5, 2026-09-10)

## Part A — iOS App Store: subscription tracker/manager landscape (US)
1. Rocket Money — 4.5★/389K ratings; subtitle "Subscription & Expense Manager"; Premium $2.99–$9.99 "pay what's fair"; free tier tracks/flags, paywalls negotiation + cancel-for-you. apps.apple.com/us/app/rocket-money-bills-budgets/id1130616675 (fetched 2026-09-10).
2. YNAB — 4.8★/~55K; $14.99/mo or $109/yr; 34-day trial; no free tier. apps.apple.com/us/app/ynab/id1010865877.
3. Bobby — 4.7★/~8K; one-time IAPs only $0.99–$2.99; free ~5 subs. apps.apple.com/us/app/bobby-track-subscriptions/id1059152023 (fetched 2026-09-10).
4. SubPilot: Cancel Subscriptions — 4.5★/4.7K; subtitle "Find & stop unwanted charges"; hybrid: Premium $9.99/$24.99/$99.99 + à la carte IAPs (Auto-Cancellation $4.99–$17.99, Free Trial Detector $39.99–$69.99, Concierge Pro $49.99–$59.99). apps.apple.com/us/app/subpilot-cancel-subscriptions/id6751181747 (fetched 2026-09-10); ilounge.com/articles/subpilot-review-2026 (2026-08-20).
5. ReSubs — 4.5★; free + premium for unlimited subs; "privacy-first… never connects to your bank"; manual/CSV/Gmail-scan/AI-screenshot import. resubs.app; apps.apple.com/us/app/resubs-subscription-manager/id6740457603.
6. Vault: Subscription Tracker — 4.5★ but 2 ratings; Yearly $7.99 / "Premium Forever" $14.99; "Your financial data never leaves your devices. No account, no trackers, no ads" + "smart screenshot import". apps.apple.com/us/app/vault-subscription-tracker/id6470649903 (fetched 2026-09-10).
7. FYM, Subkeep, SubAlert — OCR-first entrants per roundup (not verified on-listing). getfinny.app/blog/privacy-focused-subscription-trackers-2026.
8. Kudos — ~3.2/5 (low confidence, name collision); Premium ~$72/yr; auto-cancels card-linked subs. stackeasy.ai/blog/kudos-review (2026).
9. Pine AI — 4.0★/14 reviews; $29/mo flat (one source says ~20% of savings, unreconciled); claims 93% negotiation success. apps.apple.com/us/app/pine-ai-assistant-agent/id6746403769; 19pine.ai/cancel-subscription.

Wedge check: "no bank login / privacy" and "screenshot/OCR import" are claimed on-listing by Vault and ReSubs, and reported for FYM/Subkeep/SubAlert.

Shifts 2025–26: agentic cancel-for-you cohort (Pine AI, Kudos, Onepilot, SubPilot Concierge) — category moving from passive tracking to paid delegated action. Apple WWDC 2026 (Jun 8–11): cross-developer subscription bundles, group/seat subs, "Commitment Plans". macrumors.com/2026/06/11/apple-introduces-app-store-subscription-overhaul; revenuecat.com/blog/engineering/wwdc26-whats-new-for-apps.

## Part B — Monetization benchmarks
RevenueCat State of Subscription Apps 2026 (115K apps, $16B) — revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026, revenuecat.com/state-of-subscription-apps-2026-utilities (fetched 2026-09-10):
- Hard paywall vs freemium, D35 download-to-paid: 10.7% vs 2.1%; D60 revenue/install $3.09 vs $0.38.
- Trials: 17–32-day trials convert 42.5%; <4-day trials 25.5%; 55.4% of 3-day-trial cancellations happen Day 0.
- Annual-plan Year-1 cancellation ~72% (2025 edition: ~56%); 35% of annual cancellations in month 1.
- Utilities/Finance group: median D30 download-to-trial 6.5%. Global medians $5.99/wk, $10/mo, $34.80/yr.
- Only 4.6% of new apps reach $10K MRR within 2 years; median growth 5.3% YoY vs top-10% 306%.
- Lifetime: subscription+lifetime combo is the 2nd most popular monetization form (~18–24% adoption); lifetime priced 2.1x–11.5x the app's annual. revenuecat.com/blog/growth/lifetime-subscriptions.
Adapty State of In-App Subscriptions 2026 (16K apps, $3B) — adapty.io/state-of-in-app-subscriptions (fetched 2026-09-10):
- Install-to-trial 10.9%, trial-to-paid 25.6% global. Median prices $7.48/wk, $12.99/mo, $38.42/yr. Utilities trial-user 12-month LTV $68.90.
- Day-380 retention by plan: annual 19.9%, monthly 14.2%, weekly 5.5%.
- Paywall timing (secondary, rocketshiphq.com summary): "value moment" paywall 65% trial-start vs 31% for immediate onboarding hard paywall; hard paywalls +21% LTV/subscriber vs soft.
- Median app earns $492/month; 59.3% earn under $1,000 lifetime.
Superwall (40M+ paywall opens, Feb–May 2026): multi-page onboarding paywalls 12.41% vs 9.07% single-page; trial-inclusive beats no-trial in nearly every test. superwall.com/blog.
Apple Search Ads (adapty.io/apple-ads-for-subscription-apps, 2026): US blended CPI ~$2.51, CPT ~$1.58; finance-specific unverified ("Finance and Medical run high").

## 附录 D — success fee track record

# D — Contingency / success-fee track record + Apple platform rules (Sonnet 5, 2026-09-10)
| Company | Fee | Collection | Outcome | Source |
|---|---|---|---|---|
| Paribus | 25% of price-drop refunds | n/a | Acquired by Capital One 2016-10-06 → fee dropped to $0 → Capital One Shopping | techcrunch.com/2016/10/06/capital-one-acquires-online-price-tracker-paribus |
| Earny | 25% of price-protection refunds | n/a | Category collapsed as issuers withdrew price protection; Android app delisted 2024-03-31 | thewaystowealth.com/earny-review; appbrain.com |
| Harvest | 25% of recovered bank fees | n/a | Acquired by Acorns Mar 2021; lives on as in-app feature | crunchbase.com/acquisition/acorns-grow-acquires-harvest-platform |
| Cushion | commission → $4.95/mo → BNPL pivot | n/a | Shut down (announced 2025-01-30, 200K+ paying users, >$15M refunds); LendingClub acqui-hire 2025-04-29 | techcrunch.com/2025/01/30/...; prnewswire.com 2025-04-29 |
| Trim | 15% (some cite 33%) + Premium $99/yr | card on file within 7 days | Acquired by OneMain 2021-04-26; now onemainmymoney.com/bill-negotiation | investor.onemainfinancial.com (2021-04-26); cnbc.com/select/best-bill-negotiation-services (2026) |
| Rocket Money negotiation | 35–60% of first-year savings | "charged to the card you confirmed" (not IAP) | Alive; EPIC CFPB complaint re fee-slider dark pattern; no enforcement found | help.rocketmoney.com/en/articles/9744474; epic.org |
| Billshark | 40% (24-mo cap) | n/a | Alive; white-labels to credit unions (ApexEdge) | bills.com (Sept 2025); cuinsight.com |
| BillCutterz | performance %, unpublished | n/a | Alive since 2009 | cnbc.com/select (2026) |
| DoNotPay | flat ~$36/2–3 mo | subscription | FTC consent order 2025-01-16: $193K + ban on "performs like a real lawyer" claims; still operating | ftc.gov (Feb 2025); federalregister.gov 2024-09-30 |
| AirHelp | 35% (+15% if legal action) | deducted from payout | Alive, largest; 3M+ claims, $800M+ recovered (self-reported) | airhelp.com/en/price-list (2026) |
| Recoup | 25% on Full Service; free DIY Self Service | n/a | Alive 2025–26 (bank-fee + subscription refunds) | recoup.com/faq; recoup.ai/fees-back |

Platform:
- Apple Guideline 3.1.1: IAP only for digital features inside the app. 3.1.3(e) "Goods and Services Outside of the App": services consumed outside the app MUST use non-IAP payment (Apple Pay / card). developer.apple.com/app-store/review/guidelines (fetched 2026-09-10)
- Rocket Money's negotiation fee is billed to a card on file, consistent with 3.1.3(e).
- Epic v. Apple: 2025-04-30 contempt order allowed external-purchase links; 9th Cir. partially modified 2025-12-11 (Apple may charge some fee on external-link purchases). Irrelevant to real-world-service fees, which were already off-IAP. techcrunch.com 2025-05-05; macrumors.com 2025-12-11


## 6. 功能评估：「替代方案 / 重复付费」（2026-09-10 追加）

提议：对每个付费订阅显示 (a) 是否已包含在用户拥有的套餐/权益里，(b) 更便宜的档位或同类替代，(c) 流媒体「别处内容更好」。

判断（证据见附录 E）：
- (a) 「你已经有了」最强且无人做：所有追踪器（Rocket Money、SubPilot、Bobby、ReSubs、Experian）都没有；卡权益类（Kudos、CardPointers、MaxRewards）只列信用卡 credit，不与用户的付费订阅对账；Apple 只做「Save with Apple One」。确定性判断、目录小（约 25 个套餐/权益）、直接接入现有 overlap 因子。
- (b) 「更便宜的档」应以「同一服务降档 / 暂停再回来」为主，而不是「换竞品」：付费广告档用户 68%（2024 年 46%，Deloitte 2026）；41% 半年内取消过、22% 取消后回到同一服务；超过 1/3 取消者 12 个月内重新订阅（Antenna）。「同类 app」只对工具类（密码、网盘、VPN、AI）成立，流媒体由内容驱动。
- (c) 「别处内容更好」不做：JustWatch/Reelgood 的地盘（JustWatch 月访问 1.05 亿，无公开 API，数据付费授权）；内容按月变化；且内容在趋同（39% 的片库同时在 2+ 平台，2020 年 9%）。详情页放 JustWatch 外链即可。
- 维护成本：约 20 个月内 7 家服务至少 10 次调价，没有免费权威数据源，只能手工维护；Phantom 已有每日 GitHub Action 刷新远程 prices.json，替代目录同样走远程 JSON，不需发版。
- 现有缺陷顺带修复：`recomputeOverlaps` 按 6 个粗类分组，Netflix 与 Spotify 同属 entertainment 会被判为重叠，抬高僵尸分；需要更细的 kind（video/music/audiobook/cloud/password/vpn/ai/fitness/meditation/news/delivery/retail）。
- 信任：不加 affiliate（否则重演 Rocket Money 的利益冲突批评）；UI 明示「Phantom 不拿佣金」。
- 付费位置：第一条「已被覆盖」免费展示（激活时刻），全部明细 + 后续调价/套餐变化提醒归 Pro（这正是年费的持续价值）。

## 附录 E — alternatives / bundle-overlap feature evidence (Sonnet 5, 2026-09-10)

Who does it:
- Rocket Money / SubPilot / Bobby / Experian: no cheaper-alternative or bundle-overlap feature found. rocketmoney.com; subpilot.tech/about; experian.com (fetched 2026-09-10)
- ReSubs: "AI-powered savings… cancel tips" (cancel-focused; exact wording unverified, site 403). resubs.app
- Kudos "Hidden Perks": surfaces card-side statement credits; does not cross-reference paid subscriptions. joinkudos.com/blog/hidden-perks (2026-09-10)
- CardPointers ($7.50/mo or $89.99/yr) and MaxRewards ($54–108/yr) track unused card credits with expiry reminders; neither reconciles against subscriptions. thoughtcard.com/cardpointers-review; lazypoints.com (2025)
- Visa Enhanced Subscription Manager (Pinwheel): "switch" = move the payment method to the partner bank's Visa card, not switch services; 150+ merchants; NA launch summer 2026. Pinwheel survey Jan 2025: 75% expect in-app bill management. businesswire.com/news/home/20260326149948/en; pinwheelapi.com
- Apple "Save with Apple One": auto-recommends the bundle in Settings when it saves money; up to 43% claimed. apple.com/apple-one; support.apple.com/en-us/111766
- Prime Video app added "Prime" tab + icons marking content already included (date unverified). aftvnews.com
- MyBundle.tv: "Find My Bundle" cord-cutting recommender; B2B2C licensed to 185 ISPs / 10M+ customers. nctconline.org; lightreading.com
- JustWatch: ~105.3M monthly visits (Nov 2025); ads + affiliate + B2B data licensing; no public developer API. justwatch.com/us/JustWatch-Streaming-API; similarweb.com. Reelgood: 150+ services; B2B data licensing. data.reelgood.com

Behavior:
- Deloitte Digital Media Trends 2026 (3,575 US, fielded Oct–Nov 2025): 90% of households have ≥1 paid SVOD, avg 4; spend $69/mo; 73% frustrated by repeated hikes; 61% would cancel favorite on +$5/mo; 41% churned an SVOD in prior 6 months, 22% churned-and-returned; 68% pay for an ad-supported tier (46% in 2024). variety.com; mediaplaynews.com (2026)
- Antenna: ~29M "serial churners" (≈¼ of US streamers, 3+ cancels in 2 yrs), 56.5M cancels in 2023; ~⅓ of premium SVOD signups. antenna.live/insights/understanding-serial-churners (Q1'24). 2025: signups −33% YoY; >1 in 3 cancellers resubscribe within 12 months; churn 4.6%; ad-tier churn ~5% vs ad-free ~4%. antenna.live Q1'26 report (2026-02); mediaplaynews.com; thedesk.net (2025-05)
- Content overlap: 39% of US VOD titles on 2+ services by Jul 2025 (9% in 2020); 41% of high-value titles. senalnews.com citing Antenna (2025)
- YouGov 2025: 36% pay for ≥1 streaming service unused in past 6 months; 49% changed lineup in 6 months. yougov.com/en-us/reports/52727-us-media-consumption-report-2025
- Unused rewards (general, date unverified): 23% redeemed nothing in past year; ~70% carry unused rewards. creditcards.com/statistics/unused-credit-card-rewards-poll
- Not found: category-level duplicate-subscription stat (Statista paywalled); premium-card credit redemption %.

Maintenance:
- Price events: Netflix Jan 2025 ($15.49→17.99 Std; $6.99→7.99 ads; $22.99→24.99 Prem) cnbc.com 2025-01-21; Netflix again 2026-03-26 (ads $8.99, Std $19.99, Prem $26.99) techcrunch.com; Apple TV+ 2025-08-21 ($9.99→12.99) hollywoodreporter.com; Apple TV/Apple One again 2026-09-01 9to5mac.com 2026-08-28; Disney+ Oct 2025 ($11.99/$18.99); Peacock Jul 2025 (+$3) and 2026-08-18; HBO Max Oct 2026 (+$1→$10.99); Spotify 2026-01-15 ($11.99→12.99) cnbc.com; YouTube Premium Jun 2026 ($13.99→15.99) variety.com; Paramount+ 2026-01-15 (+$1). tomsguide.com roundup 2026
- No free authoritative dataset/API; JustWatch API is paid licensing; GitHub datasets are single-service/manual (github.com/tompec/netflix-prices); paid scrapers exist (apify.com ~$0.0085/result).

## 7. 实施记录（2026-09-10）

第 1、2 块已实现并通过 79 个单元测试；第 3 块按结论只放了 JustWatch 外链。

- 目录数据：`docs/data/alternatives.json`（63 服务 / 17 套餐，来源见 `alternatives-sources.json` 与 `alternatives-catalog-*-sources.md`），app 内置同一份，冷启动时远程刷新；`confidence: low` 的条目（目前仅 Equinox）在解码时丢弃。
- 付费位置：最有价值的一条「已被覆盖」免费；全部明细、具体降档方案、暂停规则、同类替代归 Pro；两类发现同时进入 Alerts 流（免费只看最新一条，与现有闸门一致）。
- 评分 v2：按 Kind 计算重叠（Netflix + Spotify 不再互相抬分）；新增覆盖、最便宜档差价、近期涨价三个因子；标定见 CLAUDE.md §5。
- 识别链路：银行的 RECURRING/MEMBERSHIP 标记在被清洗前捕获并用于判定；Apple/Google 代扣按金额拆成多条；Microsoft 365 不再显示为 GitHub；本地账本让「下月再传确认」真正生效；周期推断容忍漏扣一次；从账单本身检测涨价；目录涨价按用户实际档位匹配并立刻推送。
- 未做：重训 CoreML 分类器（保留脚本）；Amex Platinum 共享额度的去重。


## 8. 苹果订阅能否直接读取（2026-09-10 核实）

结论：没有任何公开 API 能让第三方 App 枚举用户对其他 App 的订阅。逐项核对 Apple 官方文档：

- StoreKit 2：`Transaction.all` 文档原文为 "all the customer's transactions **for your app**"；`AppTransaction.all` 为 "for this version of the app"；`Product.SubscriptionInfo.Status` 只能通过本 App 在 App Store Connect 注册的 product id 取得。developer.apple.com/documentation/storekit/transaction/all；…/apptransaction
- `AppStore.showManageSubscriptions(in:)`：只显示 "the customer's currently active subscription **for your app**"；`subscriptionGroupID` 变体只是本 App 内的分组。developer.apple.com/documentation/storekit/appstore/showmanagesubscriptions(in:)
- App Store Server API / Server Notifications：每个端点都是 "for your app"，用开发者自己的密钥签名。developer.apple.com/documentation/appstoreserverapi
- WWDC25 Advanced Commerce API、App Store 26.4 的 12 个月承诺计划、WWDC26 的订阅 Bundles/Suites：都只扩展开发者对自己 App（或联合配置的套餐）的能力，没有跨 App 读取。developer.apple.com/documentation/advancedcommerceapi；developer.apple.com/videos/play/wwdc2026/210/
- Family Sharing、Screen Time（FamilyControls/DeviceActivity）、Wallet（`PKRecurringPaymentRequest` 只能创建、不能读取）、App Intents：均无订阅枚举能力。
- `apps.apple.com/account/subscriptions`：仅深链接打开设置页，不返回数据。
- 同行印证：Bobby 手动录入；ReSubs 手动/CSV/Gmail 收据扫描/AI 截图；Subby 截图导入；SubPilot Plaid 或 Gmail/Outlook 扫描；Rocket Money Plaid。没有一家用 Apple API。

因此「接入」的实现方式是解析「设置 › 订阅」截图（`AppleSubscriptionsParser`），并用 `AppleReconciler` 把银行账单里的 `APPLE.COM/BILL $X` 与截图里的同金额条目合并，保证不重复。


## 9. 「For you」页：从订阅反推需求（2026-09-11）

用户决定榜单（Picks）先不做——代码与 CloudKit 公共库 schema 保留，Tab 换成 **For you**。

- **反推需求**：把活跃订阅按 `Kind` 归组（视频 / 音乐 / 云盘 / 密码管理 / AI / 健身 / 配送 / 运营商…）并算出每组月支出，再打习惯标签（娱乐为主、Builder、Wellness、Reader & learner、Security-minded、Convenience、Subscription-heavy）。全部在设备上由 `Recommender.build` 纯函数完成，不上传任何数据。
- **同类替代（Same job, better fit）**：目录 63 个服务、204 条替代，每条带 `edge`（free 50 / cheaper 71 / bundle 19 / better 64），按 免费 → 更便宜 → 已含在套餐里 → 更好 排序，剔除用户已经在付费的品牌，每个订阅最多 4 条，并按可省年费排序（Adobe CC → Affinity 免费，年省 $719.88）。
- **可能还需要（You might also need）**：28 条规则，按订阅组合触发（如「2 个以上视频订阅 → JustWatch / Reelgood」「云盘但没有密码管理器 → Apple Passwords / Bitwarden / 1Password」「8 个以上订阅 → 预算 app + Phantom 套餐核对」），已持有的 app 自动隐藏，每张卡写明「Because you pay for X and Y」。数据经六轮 Sonnet 5 核实（iOS 上架 + 现价）；剔除了 Mealime（2026-10-21 关停）、Postman/Bruno/Warp/camelcamelcamel（无 iOS app）、Raivo（改用 Ente Auth）。
- **付费位置**：第一个替代组 + 第一条建议免费，其余 Pro（沿用「最有价值的一条免费」原则）。演示数据下 Pro 锁显示「12 more subscriptions with alternatives … could save $2,050.68 a year」。
- **不做**：联盟链接（页脚明示）；「更好的内容」主观判断；推荐用户已在付费的 app。
- 验证：117 个单元测试通过（`RecommenderTests` 9 个），模拟器 `--demo --tab-foryou` 截图确认。目录来源：`launch/research/alternatives-replacements-sources.md`、`alternatives-suggestions-sources.md`。


## 10. 覆盖面扩张：36 个垂直领域（2026-09-11）

用户要求「增添 app 数量，尽量覆盖更多领域以及更细分的垂直需求」。瓶颈不在目录条数，而在分类法：约会、家庭安防、餐包、洗车、杀毒、理财这些高频扣费此前全部落进 `.other`，既不参与重复检测，也拿不到任何建议。

- **分类法**：`Kind` 从 22 类扩到 36 类，新增 dating / socialMedia / creatorSupport / sports / podcasts / security / email / webHosting / kids / health / mealKit / homeSecurity / auto / finance。`Category` 改为由 `Kind` 推导，新增品牌只需维护一张表。
- **重复判定按领域区分**：约会、理财、杀毒、餐包、建站、体育、家庭安防、邮箱、播客判重；创作者订阅、社交、健康、汽车、儿童不判重——两个创作者、X Premium 与 LinkedIn Premium、心理咨询与处方服务并非替代关系，误判会虚高僵尸分。
- **目录**：149 个服务 / 28 个领域 / 427 条替代（免费 133、更便宜 127、套餐已含 30、更好 67）/ 41 条建议规则。理财与安全类的建议价值最高：信用冻结免费且是法律强制、系统自带杀毒已经付过钱、简单报税有多条免费路径。此轮还拦下两处事实错误——IRS Direct File 已在 2026 报税季停用，Apple 的 Hide My Email 通用功能需要 iCloud+ 而非免费。
- **识别链路**：品牌显示名与类别补了 140+ 条，账单商户别名补了 150+ 条；不足 6 字符的别名进 `wholeWordAliases`，避免 "aura" 命中 "laura"。
- **数据来源**：六个 Sonnet 代理分组核实厂商定价页、App Store 内购列表与 Apple iTunes Search API。剔除 Amazon Freevee（2025-09-03 关停）；Nebula 官网与 App Store 价格互相矛盾且有八个价位，暂不收录。图书馆卡免费的 Kanopy 与 hoopla 是目录里最强的免费替代。
- **一次真实事故**：合并脚本放行了一个 `priceMonthly` 为空的档位，导致整份目录在客户端解析失败，被 `testBundledCatalogShipsAndParses` 当场抓到。脚本现在拒收非数字价格并在写入前重校验整份目录。
- **验证**：128 个单元测试通过，新增 `TaxonomyTests` 与 `RecommenderCatalogTests`（对真实随包目录做端到端断言）。演示数据新增约会、家庭安防、餐包、洗车四条订阅，可省年费从 $2,050 升至 $3,490。
