# FairMatch: An Explainable and Fairness-Aware Worker Recommendation Framework for Cooperative Service Marketplaces

**Devesh Ambekar**  
Department of Computer Engineering, Savitribai Phule Pune University, Pune, Maharashtra 411007, India  
*Corresponding Author Email:* `deveshambekar@outlook.com`

---

### Abstract
Digital service marketplaces frequently suffer from winner-take-all dynamics where a small fraction of highly reviewed service providers receive the vast majority of recommendation exposure, leaving qualified newcomers and part-time workers systematically excluded. This paper presents **FairMatch**, an explainable, multi-criteria worker recommendation framework engineered for **ShramSetu**, an open-source digital platform prototype for informal artisan worker cooperatives in India. FairMatch filters candidates via strict trade qualification and availability constraints, and subsequently ranks eligible artisans through a normalized multi-criteria objective combining geodesic distance, Bayesian-regularized cold-start rating, artisan trade tenure, and an inverse-workload fairness signal tracking active concurrent commitments and bookings created within the trailing 7 days that have reached completed status. 

In a synthetic simulation benchmark comprising 250 simulated artisan profiles across five trades and 1,000 sequential customer requests evaluated across five independent random seeds (5,000 total simulated transactions), FairMatch is compared against six competitive dispatch baselines: Nearest-First, Highest-Rated, Rating+Distance, Nearest + Least-Loaded, Round-Robin, and a no-fairness ablation model. Incorporating the 10% workload fairness term increases the Jain's fairness index of exposure from $0.379 \pm 0.009$ (ablation) to $0.567 \pm 0.017$ (+49.6% relative gain) and reduces worker exposure starvation from 30.41% to 17.96%, without penalizing top-1 recommendation distance (2.12 km vs. 2.38 km). Furthermore, FairMatch increases newcomer inclusion in top-5 recommendation sets from 0.00% under Highest-Rated to $11.09 \pm 0.82\%$. While spatial heuristics such as Nearest-First and Nearest+Least-Loaded exhibit high exposure equality under uniform residential demand due to geometric Voronoi dispersion, their workload equity degrades under concentrated commercial demand (Nearest-First Workload Jain drops from 0.364 to 0.087, -76.1%). Under identical clustered demand, FairMatch's dynamic inverse-workload feedback maintains a Workload Jain index of $0.322 \pm 0.016$ (+270% over Nearest-First). In-memory candidate scoring requires $O(n \log K)$ time, and PostgreSQL stored-procedure execution incurs a mean latency of 5.84 ms under strict Row Level Security boundaries, demonstrating practical viability for low-cost municipal cooperative deployments.

**Index Terms**—Algorithmic fairness, cooperative service marketplaces, explainable recommendation, gig economy, multi-criteria recommendation, multi-stakeholder ranking, worker exposure.

---

## I. Introduction

Digital service platforms increasingly mediate how local home services—including plumbing, electrical repair, carpentry, appliance maintenance, and masonry—are discovered, scheduled, and compensated. In conventional commercial gig platforms, matching and recommendation algorithms are overwhelmingly engineered to optimize consumer-side click-through, instant conversion, and aggregate transaction fees. While consumer relevance is essential, rankings in digital labor markets function as economic rationing mechanisms: a worker's position in search results strongly determines their incoming inquiries, booking volume, and sustainable livelihood [1], [2]. Audits of commercial platforms have demonstrated that unconstrained reputation-centric ranking induces severe "rich-get-richer" feedback loops: an entrenched elite of early-registered providers captures the overwhelming majority of visibility, while qualified newcomers, rural migrants, and part-time workers experience algorithmic starvation [3], [4], [9].

This concentration of economic opportunity fundamentally conflicts with the founding principles of worker cooperatives: democratic governance, equitable distribution of work, mutual welfare, and community resilience. In a cooperative marketplace, the matching engine cannot treat labor as commodified, interchangeable inventory to be hyper-concentrated on a handful of exhaustible providers. Instead, matching engines must balance consumer convenience and transit overhead with supply-side distributive equity, craft protection, and burnout prevention.

However, achieving distributive equity in physical service markets presents unique spatial and reputational challenges that distinguish it from digital content recommendation:
1. **Physical Spatial Constraints:** Recommending a worker located 20 km away to satisfy abstract exposure quotas imposes unacceptable transit overhead, fuel expenditure, and delayed service delivery. Fairness must be achieved within proximate, geographically viable candidate sets.
2. **Quality and Craft Trust:** Customers entrust service providers with entry into private homes for safety-critical repairs. Blindly round-robining unverified or substandard workers destroys customer retention and trust. Distributive fairness must operate strictly among verified, qualified candidates.
3. **Real-Time Saturation Dynamics:** Physical artisans have strict physical capacity limits ($W_i$). Allocating bookings to already saturated artisans leads to schedule slippage, lower work quality, and worker burnout, while idle members of the cooperative lose livelihoods.

To address these challenges, this paper presents **FairMatch**, an explainable, multi-criteria worker recommendation engine engineered for **ShramSetu**, an open-source platform prototype designed for informal trade worker cooperatives and municipal artisan unions in India. FairMatch unifies verified trade certification, real-time availability confirmation, spherical geodesic proximity, Bayesian-regularized cold-start rating, craft experience, and a saturation-bounded inverse-workload fairness signal into a transparent, audit-ready framework.

### Contributions
The core technical contributions of this paper are:
1. **Mathematical Multi-Criteria Formulation:** A formal recommendation framework that explicitly separates three distinct fairness dimensions (exposure, booking allocation, and physical workload saturation). We formalize an inverse-workload index with double-weighted active commitments and trailing completed bookings, prove an order-equivalence property regarding nominal vs. effective ranking weights (Proposition 1), and establish a deterministic 4-stage tie-breaking cascade.
2. **End-to-End Two-Tier Architecture:** A production implementation combining a PostgreSQL stored procedure (`fairmatch_recommend_workers`) executing server-side filtering and workload aggregation under hardened Row Level Security (RLS) boundaries, paired with an isomorphic client-side Dart engine (`FairMatchEngine`) providing human-interpretable rationale tags ("Verified Skill", "Nearby", "Top Rated", "Cooperative Partner") without exposing proprietary competitor booking schedules.
3. **Rigorous Multi-Seed Empirical Evaluation:** A reproducible empirical evaluation across 250 simulated artisan profiles and 1,000 sequential requests across five random seeds (5,000 total simulated transactions). We benchmark FairMatch against six baseline dispatch algorithms: Nearest-First, Highest-Rated, Rating+Distance, Nearest + Least-Loaded, Round-Robin, and an ablated no-fairness model. We provide full multi-factor ablation suites, parametric fairness-weight sensitivity curves, and spatial clustering stress tests across four distinct geographic topologies.

---

## II. Related Work

### A. Fairness of Exposure in Ranking
Algorithmic fairness in information retrieval and ranking has rapidly evolved from group fairness metrics toward individual and amortized exposure models. Singh and Joachims [1] formalized *Fairness of Exposure*, asserting that the aggregate attention received by items across query streams should be proportional to their intrinsic merit. Biega et al. [6] introduced *Amortized Equity of Attention*, demonstrating that because position bias prevents fair allocation within any single top-$K$ ranking list, equity must be accumulated and amortized dynamically across a sequence of rankings. Zehlike et al. [2] and Jin et al. [5] systematically surveyed learning-to-rank and fair recommendation systems. Deldjoo et al. [3] categorized fairness interventions into pre-processing, in-processing, and post-processing approaches. FairMatch functions as an in-processing mechanism: dynamic historical workload metrics directly adjust candidate utility scores at scoring time, redistributing exposure over successive query arrivals without requiring computationally prohibitive integer programming at dispatch.

### B. Multi-Stakeholder Recommendation
Modern digital marketplaces inherently operate as two-sided or multi-stakeholder ecosystems involving consumers, providers, and platform operators with competing utilities. Burke [7] established the foundational taxonomy of multi-stakeholder recommendation, distinguishing consumer-centered ($C$), provider-centered ($P$), and balanced multi-sided ($CP$) systems. Abdollahpouri et al. [8] surveyed multi-stakeholder ranking, showing that single-sided optimization inevitably marginalizes provider-side welfare. FairMatch explicitly operationalizes this multi-stakeholder trade-off: 70% of nominal criteria weight is dedicated to consumer utility (verified skill, geographic proximity, immediate availability), while 30% is allocated to provider sustainability, craft recognition, and cooperative workload distribution.

### C. Explainable and Multi-Criteria Recommendation
Multi-criteria recommendation systems decompose aggregate item utility across multiple distinct attribute ratings rather than relying on scalar preference metrics [4], [11], [18]. Linear multi-criteria formulations provide transparency and auditability, which are essential for algorithmic management in labor settings [16], [17]. In labor platforms, opaque black-box dispatch algorithms alienate workers and foster distrust. FairMatch uses a transparent linear formulation paired with qualitative explanation tags derived directly from criterion thresholds, enabling cooperative members to inspect the explicit rationale behind recommendation rankings without revealing private competitor booking data.

### D. Multi-Period Matching and Load-Aware Dispatch
In on-demand transportation and delivery systems, dynamic dispatch has been formulated via bipartite matching [10], [12] and online task assignment [15], [19], [20]. Sühr et al. [12] formulated two-sided fairness in ride-hailing via repeated matching optimization. However, global optimization formulations require centralized batching windows and significant server compute infrastructure. In municipal artisan cooperatives, dispatch must operate with near-zero latency on low-cost serverless databases and intermittently connected mobile devices. FairMatch fills this practical gap by providing a deterministic, per-query scoring function that achieves load-aware distribution directly within standard relational database indexes.

---

## III. ShramSetu System Context and Security Architecture

```
+-----------------------------------------------------------------------------+
|                          ShramSetu Two-Tier Architecture                     |
+-----------------------------------------------------------------------------+
|  CLIENT TIER (Flutter / Dart)                                               |
|  - UI Presentation Layer (Worker Discovery Screen, Badges)                  |
|  - Service Layer (FairMatchService)                                         |
|  - Local Engine (FairMatchEngine.dart) -> Qualitative Rationale Badges      |
|    ("Verified Skill", "Nearby", "Top Rated", "Cooperative Partner")        |
+-----------------------------------------------------------------------------+
                                      |
                     RPC Request (service_id, lat, lon)
                     Protected Supabase JWT Auth (Bearer)
                                      v
+-----------------------------------------------------------------------------+
|  DATABASE TIER (PostgreSQL / Supabase)                                      |
|  - Function: fairmatch_recommend_workers(...)                                |
|    * Privileges: SECURITY DEFINER, Owner: fairmatch_definer (NOLOGIN)      |
|    * Fixed Search Path: SET search_path = public, pg_temp                   |
|    * Caller Authorization: REVOKE FROM PUBLIC; GRANT TO authenticated       |
|                                                                             |
|  1. Candidate Filtering (idx_worker_skills_skill_worker)                    |
|     WHERE is_available = true AND worker_status = 'ACTIVE'                  |
|  2. Geographic Distance Calculation (In-Kernel Haversine Formula)           |
|  3. Workload Aggregation (Cross-Worker Saturation via RLS Policy)           |
|     - Active Commitments: status IN ('accepted','onTheWay','arrived',...)   |
|     - Trailing Completed: status = 'completed' AND created_at >= NOW()-7d  |
|  4. Multi-Criteria Composite Scoring & 4-Stage Tie-Breaking Cascade         |
|  5. Procedural JSONB Masking & Audit Logging (public.fairmatch_logs)        |
+-----------------------------------------------------------------------------+
```
*Fig. 1. End-to-end architecture of the FairMatch recommendation framework in ShramSetu.*

### A. Application and Schema Design
ShramSetu is architectured as a multi-tier Flutter client backed by Supabase and PostgreSQL. The relational schema strictly separates authentication and user records (`public.users`), artisan professional profiles (`public.workers`), trade certifications (`public.worker_skills`), the municipal service catalog (`public.services`), and booking contracts (`public.bookings`). Recommendation ranking is encapsulated server-side within the PostgreSQL function `fairmatch_recommend_workers`, which accepts a target service UUID, customer GPS coordinates, custom criterion weights (with defaults matching Table I), a candidate limit $K$, and an algorithm selector string.

### B. Security Architecture, Privilege Boundaries, and Threat Mitigation
A critical requirement in cooperative labor platforms is preventing competitor reconnaissance, schedule harvesting, and client-side data scraping. The security boundary governing FairMatch in PostgreSQL is structured as follows:

1. **Dedicated Definer Role vs. Superuser Execution:** In prototype deployments, functions created under default administrative scripts inherit ownership by the database superuser (`postgres`). Running a `SECURITY DEFINER` routine as a superuser represents a high-impact privilege boundary: any procedural vulnerability or injection could compromise the entire database cluster. For production hardening, we specify a dedicated, least-privileged role architecture:
```sql
CREATE ROLE fairmatch_definer NOLOGIN;
GRANT SELECT ON public.workers, public.worker_skills, public.services, public.bookings TO fairmatch_definer;
GRANT INSERT ON public.fairmatch_logs TO fairmatch_definer;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY fairmatch_definer_read_all ON public.bookings FOR SELECT TO fairmatch_definer USING (true);
ALTER FUNCTION public.fairmatch_recommend_workers OWNER TO fairmatch_definer;
```
By creating `fairmatch_definer` with `NOLOGIN`, the role cannot be authenticated directly from external clients. By granting an explicit RLS policy to `fairmatch_definer` on `public.bookings`, cross-worker aggregation is authorized within the function kernel without requiring `BYPASSRLS` or superuser privileges.

2. **Role-Scoped Execution Permissions:** By default, PostgreSQL grants execute permissions on newly created functions to `PUBLIC`. FairMatch explicitly restricts access:
```sql
REVOKE EXECUTE ON FUNCTION public.fairmatch_recommend_workers FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fairmatch_recommend_workers TO authenticated;
```
This ensures that anonymous web scrapers cannot invoke the matching engine.

3. **Hardened Search Path:** To mitigate search-path injection vulnerabilities where an attacker could create temporary objects to intercept execution, the stored procedure enforces a pinned search path: `SET search_path = public, pg_temp;` where `pg_temp` is placed last. All internal SQL queries explicitly qualify table names (`public.workers`, `public.bookings`, `public.worker_skills`).

4. **Procedural Encapsulation:** Table-level RLS policies on `public.bookings` restrict normal client roles strictly to rows where `customer_id = auth.uid() OR worker_id = auth.uid()`. Security is enforced through procedural encapsulation: client roles possess `EXECUTE` privileges on the function, but direct `SELECT` on `public.bookings` remains prohibited. The function accepts validated parameters, queries only indexed aggregates, and returns a sanitized JSONB document containing public worker profile attributes and qualitative explanation tags. Competitor booking IDs, customer UUIDs, customer coordinates, earnings, and raw booking timestamps are never exposed.

5. **Audit Logging Privilege Architecture:** Inside a `SECURITY DEFINER` function, PostgreSQL evaluates table permissions and Row Level Security under the database role of the function owner (`fairmatch_definer`), rather than the calling role (`authenticated`). Consequently, `public.fairmatch_logs` does not require—and should not grant—direct `INSERT` permissions to client roles. Instead, `fairmatch_definer` must be explicitly granted `INSERT` on `public.fairmatch_logs`, accompanied by an explicit RLS policy:
```sql
GRANT INSERT ON public.fairmatch_logs TO fairmatch_definer;
CREATE POLICY fairmatch_definer_insert ON public.fairmatch_logs FOR INSERT TO fairmatch_definer WITH CHECK (true);
```
Caller provenance is safely recorded because PostgreSQL preserves the authenticated session context; `auth.uid()` evaluates to the client's UUID, which the stored procedure writes to `fairmatch_logs.customer_id`. To safeguard service discovery, migration 013 wraps the log insertion in an exception-handling block (`BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END;`), ensuring that any logging failure or permission anomaly fails open for customer recommendations rather than interrupting service delivery. Platform administrators possess exclusive `SELECT` access (`auth_user_role() = 'ADMIN'`), and no `UPDATE` or `DELETE` grants or policies exist for non-superuser roles, establishing an append-only audit trail.

---

## IV. FairMatch Recommendation Framework

### A. Formal Problem Formulation
Let $q = (s, l_c, t_r)$ denote a customer service request where $s \in \text{public.services}$ represents the required trade, $l_c = (\text{lat}_c, \text{lon}_c)$ represents customer GPS coordinates, and $t_r$ is the query timestamp. Let $\mathcal{W} = \{w_1, w_2, \dots, w_N\}$ denote the complete platform registry of registered artisans.

The eligible candidate set $\mathcal{W}(q) \subseteq \mathcal{W}$ is strictly filtered prior to scoring through mandatory eligibility predicates:
$$\mathcal{W}(q) = \left\{ w_i \in \mathcal{W} \;\middle|\; 
\begin{aligned}
&w_i.\text{worker\_status} = \text{'ACTIVE'} \;\land\\
&w_i.\text{is\_available} = \text{true} \;\land\\
&(w_i.\text{id}, s) \in \text{public.worker\_skills} \;\land\\
&w_i.\text{id} \in \text{public.users}
\end{aligned}
\right\}$$

Candidates failing any eligibility predicate are pruned immediately. A high score on one criterion cannot compensate for a failed eligibility constraint.

### B. Multi-Criteria Scoring Formulation
For each eligible worker $w_i \in \mathcal{W}(q)$, FairMatch computes six individual criterion scores, each strictly normalized to $[0.0, 1.0]$:

1. **Skill Compatibility ($S_{\text{skill}}$) and Immediate Availability ($S_{\text{avail}}$):** Binary confirmation of trade certification and dispatch availability:
$$S_{\text{skill}}(w_i, q) = 1.0, \quad S_{\text{avail}}(w_i, q) = 1.0 \quad \forall w_i \in \mathcal{W}(q)$$

2. **Geographic Proximity Score ($S_{\text{dist}}$):** Geodesic distance $d(l_c, l_{w_i})$ in kilometers is computed using the spherical Haversine formula with Earth radius $R = 6371.0\text{ km}$:
$$S_{\text{dist}}(w_i, q) = \max\left(0.0, \min\left(1.0, 1.0 - \frac{d(l_c, l_{w_i})}{d_{\max}}\right)\right) \tag{1}$$
where $d_{\max} = 15.0\text{ km}$ (or $3.5\text{ km}$ for municipal ward dispatch). When customer coordinates are omitted or a worker profile lacks GPS coordinates, a neutral fallback score of $S_{\text{dist}} = 0.5$ is assigned (equivalent to an imputed distance of $7.5\text{ km}$). This fallback places missing-coordinate workers behind verified local candidates closer than 7.5 km and ahead of distant candidates beyond 7.5 km, preventing exclusionary rejection while maintaining proximity priority.

3. **Rating Score with Cold-Start Correction ($S_{\text{rating}}$):** Historical customer ratings are mapped to $[0.0, 1.0]$ via $(r_i - 1.0) / 4.0$. To prevent unreviewed newcomers from being permanently locked out, a neutral cold-start baseline of $S_{\text{rating}} = 0.5$ (equivalent to 3.0 stars) is assigned when $n_{\text{rev},i} = 0$:
$$S_{\text{rating}}(w_i) = \begin{cases}
\text{clamp}\left(\frac{r_i - 1.0}{4.0}, 0.0, 1.0\right), & \text{if } n_{\text{rev},i} > 0 \\
0.5, & \text{if } n_{\text{rev},i} = 0
\end{cases} \tag{2}$$

4. **Professional Experience Score ($S_{\text{exp}}$):** Trade tenure in years normalized linearly against a ten-year cooperative mastery ceiling:
$$S_{\text{exp}}(w_i) = \min\left(1.0, \frac{y_i}{10.0}\right) \tag{3}$$

5. **Workload-Distribution Fairness Score ($S_{\text{fair}}$):** The distributive equity term penalizes over-utilized workers and boosts idle members. Let $A_i$ denote active concurrent bookings (status `accepted`, `onTheWay`, `arrived`, `inProgress`). In the database implementation, recent completed work is evaluated via:
$$\text{COUNT}(*) \text{ FROM public.bookings WHERE worker\_id} = w_i \land \text{status} = \text{'completed'} \land \text{created\_at} \ge (\text{NOW}() - 7\text{ days})$$
We designate this term $C_{\text{created}\_7d,i}$. Crucially, this measures the count of bookings created within the previous seven days that have reached completed status. It does not measure all work completed in the trailing seven days regardless of creation date (e.g., a booking initiated 8 days ago and completed yesterday is excluded). Cancelled and rejected bookings represent non-performed jobs and are strictly excluded. The composite workload index $W_i$ and normalized fairness score $S_{\text{fair}}$ are defined as:
$$W_i = 2.0 \cdot A_i + C_{\text{created}\_7d,i} \tag{4}$$
$$S_{\text{fair}}(w_i) = \max\left(0.0, \min\left(1.0, 1.0 - \frac{\min(10.0, W_i)}{10.0}\right)\right) \tag{5}$$
Active bookings carry double weight (2.0) to prioritize immediate real-time load shedding, while completed jobs capture cumulative recent saturation. At $W_i = 0$, an idle worker receives the maximum bonus $S_{\text{fair}} = 1.0$; at $W_i \ge 10.0$, the score saturates at 0.0.

The composite utility score $S(w_i, q)$ is the weighted linear sum:
$$S(w_i, q) = \sum_k w_k \cdot S_k(w_i, q), \quad k \in \{\text{skill}, \text{dist}, \text{avail}, \text{rating}, \text{exp}, \text{fair}\} \tag{6}$$

### C. Proposition 1: Order Equivalence and Effective Weights
**Proposition 1 (Order Equivalence):** Under nominal weights $\mathbf{w} = (0.35, 0.20, 0.15, 0.10, 0.10, 0.10)$, ranking candidates over $\mathcal{W}(q)$ by $S(w, q)$ is strictly identical to ranking by the reduced utility function:
$$S'(w, q) = 0.40 \cdot S_{\text{dist}} + 0.20 \cdot S_{\text{rating}} + 0.20 \cdot S_{\text{exp}} + 0.20 \cdot S_{\text{fair}}$$

*Proof:* For all $w_i \in \mathcal{W}(q)$, $S_{\text{skill}} = 1.0$ and $S_{\text{avail}} = 1.0$. Substituting these values into Eq. (6):
$$\begin{aligned}
S(w_i, q) &= 0.35(1.0) + 0.15(1.0) + 0.20 S_{\text{dist}} + 0.10 S_{\text{rating}} + 0.10 S_{\text{exp}} + 0.10 S_{\text{fair}} \\
&= 0.50 + 0.50 \left( 0.40 S_{\text{dist}} + 0.20 S_{\text{rating}} + 0.20 S_{\text{exp}} + 0.20 S_{\text{fair}} \right) \\
&= 0.50 + 0.50 \cdot S'(w_i, q)
\end{aligned}$$
Since $g(x) = 0.50 + 0.50x$ is strictly monotonically increasing for all $x \in \mathbb{R}$, $S(w_a, q) > S(w_b, q) \iff S'(w_a, q) > S'(w_b, q)$ for all $w_a, w_b \in \mathcal{W}(q)$. $\blacksquare$

| Criterion | Nominal Weight ($w_k$) | Effective Weight ($w'_k$) | Mathematical Normalization Formula |
| :--- | :---: | :---: | :--- |
| **Trade Skill** | 35.0% | 0.0% (Hard Filter) | $S_{\text{skill}} = 1.0$ on $\mathcal{W}(q)$ |
| **Geodesic Distance** | 20.0% | 40.0% | $\max(0, 1 - d / 15.0)$; imputed $0.5$ if missing |
| **Availability** | 15.0% | 0.0% (Hard Filter) | $S_{\text{avail}} = 1.0$ on $\mathcal{W}(q)$ |
| **Rating (Cold-Start)** | 10.0% | 20.0% | $(r - 1.0)/4.0$; imputed $0.5$ for unreviewed |
| **Experience** | 10.0% | 20.0% | $\min(1.0, \text{tenure}/10.0)$ |
| **Workload Fairness** | 10.0% | 20.0% | $1.0 - \min(10.0, 2A + C_{\text{created}\_7d})/10.0$ |
*Table I. Nominal vs. effective criteria weights in FairMatch.*

### D. Implementation Versions and Deterministic Tie-Breaking Cascade
To eliminate arbitrary sorting, FairMatch implements a deterministic four-level tie-breaking cascade. We distinguish the following architectural versions and execution environments:

1. **Experimental Benchmark Algorithm (v1):** All empirical results reported in this paper evaluate the **v1 algorithm**, defined in migration `013_fairmatch_engine.sql`. In v1, the operational distance ceiling is $d_{\max} = 15.0\text{ km}$, and ties are broken deterministically by: 1) total score (descending), 2) skill score (descending), 3) geodesic distance (ascending), and 4) worker UUID (ascending lexicographically).
2. **Client-Side Scoring & Explanation Engine (`FairMatchEngine.dart`):** Implemented in Flutter/Dart (`app/lib/core/services/fairmatch_engine.dart`). The client engine implements the **v1 comparator locally** (totalScore DESC, skillScore DESC, distanceKm ASC, worker.id ASC) to produce offline UI rankings and generate explanation badges without querying sensitive competitor booking records.
3. **Production Ward-Level Revision (v2):** Defined in migration `029_booking_payment_and_dispatch.sql`. Migration 029 represents a subsequent production enhancement tailored for hyper-local municipal-ward dispatch: it tightens distance normalization to a strict $3.5\text{ km}$ ward ceiling ($S_{\text{dist}} = \max(0, 1 - d/3.5)$) and introduces a workload-equity tie-breaking cascade: 1) total score DESC, 2) lifetime completed jobs ASC (directly favoring underutilized members with fewer lifetime jobs), 3) experience DESC (rewarding trade tenure), and 4) worker UUID ASC. The v2 revision was not evaluated in the multi-seed benchmark and is documented here for production architectural completeness.

```
Algorithm 1: FairMatch Multi-Criteria Recommendation (v1)
Input: Query q = (s, l_c), Worker registry W, Weights w, Limit K
Output: Top-K Ranked List L_K with Explanation Badges
1:  W(q) <- { w in W | w.worker_status = 'ACTIVE' and w.is_available = true 
                      and (w.id, s) in worker_skills and w.id in users }
2:  if W(q) is empty then return []
3:  for each worker w_i in W(q) do
4:      d_i <- Haversine(l_c, w_i.location) [or 7.5 km if unresolvable]
5:      S_dist <- max(0, min(1, 1 - d_i / 15.0))
6:      S_rating <- (w_i.review_count > 0) ? clamp((w_i.rating - 1)/4, 0, 1) : 0.5
7:      S_exp <- min(1.0, w_i.experience_years / 10.0)
8:      W_i <- 2.0 * w_i.active_bookings + w_i.completed_7d_bookings
9:      S_fair <- max(0, min(1, 1 - min(10.0, W_i) / 10.0))
10:     S_total <- 0.35(1) + 0.20*S_dist + 0.15(1) + 0.10*S_rating + 0.10*S_exp + 0.10*S_fair
11:     badges_i <- GenerateBadges(w_i, d_i, S_dist, S_rating, S_exp, S_fair)
12: sort W(q) by S_total DESC, S_skill DESC, d_i ASC, w_i.id ASC
13: L_K <- first K elements of sorted W(q)
14: L_K[0].badges.append("FairMatch Recommended")
15: return L_K
```

### E. Feature-Grounded Explanation Badges
FairMatch generates deterministic rule-based explanation badges directly from verified feature scores:
- **"Verified Skill"**: Conferred when $S_{\text{skill}} \ge 0.90$.
- **"Available Now"**: Conferred when $S_{\text{avail}} \ge 0.90$.
- **"Nearby"**: Conferred when $d(l_c, l_{w_i}) \le 3.5\text{ km}$ or $S_{\text{dist}} \ge 0.60$.
- **"Top Rated"**: Conferred when rating $\ge 4.50$ with $n_{\text{rev}} \ge 1$; otherwise **"Good Rating"** if $S_{\text{rating}} \ge 0.60$.
- **"Veteran Artisan"**: Conferred when craft tenure $\ge 8\text{ years}$; otherwise **"Experienced"** if tenure $\ge 4\text{ years}$.
- **"Cooperative Partner"**: Conferred when $S_{\text{fair}} \ge 0.70$ (indicating low physical workload $W_i \le 3.0$).
- **"FairMatch Recommended"**: Conferred exclusively on the rank #1 candidate.

### F. Computational Complexity and Execution Profiling
To establish computational tractability, we separate in-memory algorithmic complexity from server-side database query execution:

1. **In-Memory Scoring Complexity:** For an admitted candidate set $\mathcal{W}(q)$ of size $n$, in-memory feature normalization and weighted scoring require $O(1)$ arithmetic operations per candidate, giving $O(n)$ total scoring complexity. Sorting $n$ candidates requires $O(n \log n)$, which reduces to $O(n \log K)$ when selecting the top-$K$ candidates via a bounded min-heap. In municipal ward dispatch ($n \approx 50$ per trade, $K = 5$), in-memory execution takes less than 10 microseconds ($0.008\text{ ms}$ in Table II-B).
2. **Server-Side Database RPC Execution Complexity:** The server-side PostgreSQL function performs indexed filtering and workload aggregation before scoring:
   - Candidate filtering performs an index scan on `idx_worker_skills_skill_worker`, requiring $O(\log S + n)$ time, where $S$ is the total skills registry and $n = |\mathcal{W}(q)|$ is the eligible candidate set for trade $s$.
   - Workload aggregation in the current implementation executes **two correlated scalar subqueries per admitted candidate**: one querying active commitments (`status IN ('accepted', 'onTheWay', 'arrived', 'inProgress')`) and one querying recently created completed bookings (`status = 'completed' AND created_at >= NOW() - 7d`). Because `idx_bookings_worker_status_created` indexes `(worker_id, status, created_at)`, each correlated count executes an index seek and range scan in $O(\log B + b_i)$ time, where $B$ is the total bookings table size and $b_i$ is candidate $i$'s booking count. Across $n$ candidates, the database executes $2n$ correlated index scans, incurring $O(n \log B)$ time.
   - While an alternative grouped join (`LEFT JOIN (SELECT worker_id, ... FROM bookings GROUP BY worker_id)`) could scan relevant bookings in a single pass, the correlated subquery structure was chosen for procedural simplicity and low query-planner overhead in PL/pgSQL given small candidate sets ($n \approx 50$).
   - Total server-side database complexity is therefore $O(\log S + n \log B + n \log K)$, which empirically completes in a mean of $5.84\text{ ms}$ on the prototype database (Section V-H).

---

## V. Experimental Evaluation

### A. Research Questions
- **RQ1 (Relevance & Quality):** Does FairMatch recommend high-quality, geographically proximal workers without sacrificing service standards?
- **RQ2 (Distributive Equity):** How does the fairness term alter recommendation exposure, booking allocation, and workload saturation across the worker collective compared to standard baselines?
- **RQ3 (Starvation & Cold-Start):** Does FairMatch reduce worker starvation and provide discovery pathways for newly registered, unreviewed artisans?
- **RQ4 (Geographic Demand Clustering):** How do FairMatch and Nearest-First behave when customer requests concentrate into dense urban commercial hubs?
- **RQ5 (Computational Efficiency):** Can the multi-criteria ranking algorithm execute within real-time mobile and database latency budgets?

### B. Benchmark Setup
The benchmark environment models an urban municipal cooperative in Pune, India ($18.5204^\circ\text{ N}, 73.8567^\circ\text{ E}$). The candidate pool comprises $N = 250$ synthetic worker profiles uniformly partitioned across five service trades: Plumber, Electrician, Carpenter, Cleaner, and Painter. Coordinates are dispersed within a 10 km urban radius. Ratings follow a truncated normal distribution (mean = 4.35, std = 0.45) bounded in $[1.0, 5.0]$, with 15% designated as newly registered cold-start workers (0 reviews). Professional experience spans 1 to 15 years.

Each algorithm processes a sequential stream of 1,000 customer requests across five independent random seeds (42, 101, 777, 2024, 9999), generating 5,000 total simulated transactions. All metrics are reported as mean $\pm$ sample standard deviation across the five seeds.

### C. The Three Fairness Dimensions and Closed-Loop Feedback Process
A central methodological distinction is separating three interrelated fairness concepts:
1. **Recommendation Exposure Fairness ($x_i$):** Position-discounted attention accumulated in top-5 recommendation sets:
$$x_i = \sum_t \sum_{r=1}^K I(w_i = L_t[r]) \cdot \frac{1}{\log_2(r + 1)}$$
2. **Booking Allocation Fairness ($B_i$):** Confirmed customer commissioning conversions:
$$B_i = \sum_t I(\text{customer selects } w_i \text{ from } L_t)$$
3. **Physical Workload Saturation ($W_i$):** Actual physical labor commitments at time $t$:
$$W_i(t) = 2.0 A_i(t) + C_{\text{created}\_7d,i}(t)$$

These three dimensions interact through a dynamic closed-loop feedback process:
$$\text{Recommendation } L_K(q) \longrightarrow \text{Customer Choice } P(r) \longrightarrow \text{Booking } B_i \longrightarrow \text{Workload Update } W_i(t) \longrightarrow \text{Subsequent Scoring } S_{\text{fair}}(w_i)$$

**Customer Choice Model and Lifecycle Alignment:** Customers choose rank 1, 2, or 3 with empirical cascade probabilities 0.60, 0.25, and 0.15 respectively (ranks 4 and 5 accrue exposure but zero direct bookings). Exactly one booking is created per request. In strict accordance with Eq. (4), booking commissioning increments only active concurrent commitments ($A_i$). Completed bookings ($C_i$) are incremented strictly when active commitments transition to completed status during stochastic decay, ensuring complete mathematical fidelity between the formalized index and the simulation engine. Specifically, when booked, the commissioned worker's `activeBookings` increments by 1. Active bookings decay stochastically every 10 requests (40% completion probability), modeling physical job execution in the field. When an active job completes, `activeBookings` decrements and `recent7dBookings` increments. Completed 7-day bookings decay every 50 requests (25% aging-out probability). Each algorithm is evaluated across five independent random seeds (42, 101, 777, 2024, 9999), yielding 5,000 total simulated transactions.

### D. Baseline Comparison

| Algorithm | Exposure Jain (↑) | Booking Jain (↑) | Workload Jain (↑) | Top 10% Share | Exp Starvation | Book Starvation |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Nearest-First** | 0.772 ± 0.029 | 0.653 ± 0.028 | 0.364 ± 0.027 | 19.27% ± 1.13% | 10.45% ± 0.45% | 21.05% ± 1.70% |
| **Highest-Rated** | 0.106 ± 0.004 | 0.064 ± 0.004 | 0.055 ± 0.003 | 90.40% ± 0.81% | 86.94% ± 0.74% | 91.80% ± 0.68% |
| **Rating + Distance** | 0.436 ± 0.015 | 0.324 ± 0.012 | 0.211 ± 0.009 | 35.11% ± 1.25% | 25.93% ± 1.70% | 45.47% ± 1.34% |
| **Nearest + Least-Loaded** | 0.798 ± 0.028 | 0.740 ± 0.027 | 0.497 ± 0.024 | 17.95% ± 1.08% | 10.45% ± 0.45% | 13.91% ± 1.14% |
| **Round-Robin** | 0.852 ± 0.020 | 0.750 ± 0.016 | 0.440 ± 0.019 | 15.34% ± 0.59% | 10.45% ± 0.45% | 12.83% ± 1.05% |
| **Ablation (wfair=0)** | 0.379 ± 0.009 | 0.282 ± 0.008 | 0.187 ± 0.011 | 38.82% ± 0.95% | 30.41% ± 1.48% | 49.40% ± 1.99% |
| **FairMatch v1** | **0.567 ± 0.017** | **0.508 ± 0.017** | **0.403 ± 0.024** | **25.89% ± 0.60%** | **17.96% ± 2.07%** | **30.76% ± 2.27%** |
*Table II-A. Baseline comparison: Multi-dimensional fairness, exposure, and allocation (mean ± std dev, 5 seeds).*

| Algorithm | Top-1 Dist (km) | Top-1 Rating | Top-1 Exp (yrs) | Cold-Start in Top-5 | Scoring Latency |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Nearest-First** | 1.42 ± 0.04 | 4.08 ± 0.02 | 6.52 ± 0.23 | 18.42% ± 0.47% | 0.012 ± 0.002 ms |
| **Highest-Rated** | 6.66 ± 0.17 | 5.00 ± 0.00 | 6.27 ± 0.12 | 0.00% ± 0.00% | 0.008 ± 0.001 ms |
| **Rating + Distance** | 2.20 ± 0.06 | 4.72 ± 0.01 | 6.51 ± 0.15 | 0.47% ± 0.28% | 0.007 ± 0.001 ms |
| **Nearest + Least-Loaded** | 1.59 ± 0.04 | 4.07 ± 0.03 | 6.46 ± 0.24 | 10.45% ± 0.45% | 0.010 ± 0.002 ms |
| **Round-Robin** | 8.29 ± 0.10 | 4.07 ± 0.03 | 6.50 ± 0.23 | 10.45% ± 0.45% | 0.009 ± 0.001 ms |
| **Ablation (wfair=0)** | 2.38 ± 0.07 | 4.44 ± 0.06 | 10.11 ± 0.22 | 7.67% ± 1.08% | 0.006 ± 0.000 ms |
| **FairMatch v1** | **2.12 ± 0.04** | **4.27 ± 0.04** | **9.15 ± 0.25** | **11.09% ± 0.82%** | **0.008 ± 0.001 ms** |
*Table II-B. Baseline comparison: Service quality, proximity, and scoring latency (mean ± std dev, 5 seeds).*

### E. Experimental Results and Trade-Off Analysis

**1) Geometric Voronoi Nature of Nearest-First under Uniform Demand:** Nearest-First achieves high exposure equality ($0.772 \pm 0.029$) under uniform demand. This occurs because uniformly distributed customer coordinates partition the municipal space into balanced Voronoi tessellations around workers: customers across neighborhoods naturally select different nearby workers. This exposure distribution is a geometric byproduct of geographic demand dispersion rather than an active fairness optimization. Crucially, Nearest-First completely ignores service quality (average rating is only 4.08 vs. 4.27 for FairMatch) and trade tenure (6.52 vs. 9.15 years), and fails when customer demand concentrates spatially.

**2) The Physical Cost of Round-Robin and Pure Workload Dispatch:** Round-Robin achieves high exposure equality ($0.852$) and booking equality ($0.750$), but incurs an unviable mean top-1 transit distance of $8.29\text{ km}$—a 291% travel distance penalty over FairMatch ($2.12\text{ km}$). In municipal artisan services, forcing artisans to travel across entire cities destroys operational viability. Nearest + Least-Loaded achieves strong exposure equality ($0.798$) and proximity ($1.59\text{ km}$), but lacks quality controls (delivering lower ratings of 4.07). FairMatch achieves a balanced, multi-stakeholder compromise across proximity, quality, and equity.

**3) Multi-Criteria Value of the Fairness Term:** Compared directly to the ablated baseline ($w_{\text{fair}} = 0.0$), introducing the 10% workload fairness term delivers a **+49.6% relative improvement** in exposure Jain index ($0.379 \to 0.567$), an **+80.1% relative improvement** in booking Jain index ($0.282 \to 0.508$), and a **+115.0% relative improvement** in physical workload Jain index ($0.187 \to 0.403$), while reducing worker exposure starvation from 30.41% to 17.96% and booking starvation from 49.40% to 30.76%. Mean top-1 transit distance improves from $2.38\text{ km}$ to $2.12\text{ km}$.

**4) Newcomer Inclusion and Starvation Mitigation (RQ3):** Under reputation-centric ranking (Highest-Rated), unreviewed newcomers are 100% excluded ($0.00\%$ top-5 share) and 86.94% of the worker collective experiences total exposure starvation. Rating+Distance exhibits similar exclusion ($0.47\%$ newcomer share). FairMatch's neutral cold-start baseline ($S_{\text{rating}} = 0.5$) combined with the inverse-workload bonus secures **$11.09 \pm 0.82\%$** of top-5 slots for unreviewed newcomers, providing a genuine algorithmic entry pathway.

---

### F. Multi-Factor Ablation Study and the Artisan Seniority Trade-Off

| Ablation Configuration | Jain's Index (↑) | Gini Coeff (↓) | Exposure Starvation | Top-1 Dist (km) | Top-1 Rating |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Full FairMatch v1** | **0.567 ± 0.017** | **0.492 ± 0.010** | **17.96% ± 2.07%** | **2.12 ± 0.04** | **4.27 ± 0.04** |
| **No Fairness (wfair=0)** | 0.379 ± 0.009 | 0.643 ± 0.007 | 30.41% ± 1.48% | 2.38 ± 0.07 | 4.44 ± 0.06 |
| **No Distance (wdist=0)** | 0.491 ± 0.021 | 0.551 ± 0.017 | 37.49% ± 2.21% | 6.72 ± 0.16 | 4.31 ± 0.04 |
| **No Rating (wrate=0)** | 0.601 ± 0.019 | 0.468 ± 0.012 | 16.03% ± 1.62% | 2.05 ± 0.04 | 4.09 ± 0.04 |
| **No Experience (wexp=0)** | 0.722 ± 0.023 | 0.366 ± 0.016 | 10.45% ± 0.45% | 1.80 ± 0.04 | 4.34 ± 0.03 |
*Table III. Multi-factor ablation study (mean ± std dev, 5 seeds).*

**The Artisan Seniority Trade-Off:** In Table III, zeroing the experience term ($w_{\text{exp}} = 0$) causes exposure Jain index to rise from 0.567 to 0.722, cuts exposure starvation to 10.45%, and reduces top-1 distance from 2.12 km to 1.80 km. Removing the rating term ($w_{\text{rating}} = 0$) similarly increases exposure Jain to 0.601. 

This behavior highlights a fundamental principle of multi-criteria ranking: **Experience and rating function as selective merit constraints.** Because high experience (tenure $\ge 10\text{ years}$) and high ratings are concentrated among specific artisan subsets, weighting them naturally restricts the pool of top-scoring candidates. When experience is removed, ranking becomes dominated by proximity and workload fairness, dispersing exposure more evenly across the geographic map.

In ShramSetu, the 10% experience weight is not intended as an algorithmic fairness booster; it is an **explicit cooperative policy constraint**. Artisan guilds and trade unions explicitly require platform dispatch to honor craft longevity and apprenticeship tenure. FairMatch's multi-criteria framework allows cooperative federations to tune this trade-off transparently based on democratic collective agreements.

---

### G. Parametric Sensitivity Analysis over Fairness Weight

| Fairness Weight | Exp Jain (↑) | Book Jain (↑) | Workload Jain (↑) | Top 10% Share | Exp Starv (%) | Book Starv (%) | Top-1 Dist | Top-1 Rating |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| $w_{\text{fair}} = 0.00$ | 0.3793 | 0.2823 | 0.1874 | 38.82% | 30.41% | 49.40% | 2.38 km | 4.44 |
| $w_{\text{fair}} = 0.05$ | 0.4908 | 0.4079 | 0.3013 | 29.77% | 23.17% | 38.85% | 2.12 km | 4.33 |
| $w_{\text{fair}} = 0.10$ (Default) | **0.5667** | **0.5083** | **0.4030** | **25.89%** | **17.96%** | **30.76%** | **2.12 km** | **4.27** |
| $w_{\text{fair}} = 0.15$ | 0.6232 | 0.5841 | 0.4851 | 23.51% | 15.55% | 24.63% | 2.24 km | 4.25 |
| $w_{\text{fair}} = 0.20$ | 0.6665 | 0.6382 | 0.5476 | 22.56% | 13.59% | 21.04% | 2.40 km | 4.23 |
*Table IV. Parametric sensitivity sweep over fairness weight (5 seeds).*

Table IV documents the parametric sensitivity progression across fairness weights. In this verified re-run, exposure starvation falls monotonically from 30.41% ($w_{\text{fair}} = 0.00$) to 23.17% ($w_{\text{fair}} = 0.05$), 17.96% ($w_{\text{fair}} = 0.10$), 15.55% ($w_{\text{fair}} = 0.15$), and 13.59% ($w_{\text{fair}} = 0.20$), while top-10% share decreases from 38.82% to 22.56%, fully resolving the preliminary draft artifact where 26.69% was erroneously duplicated.

As $w_{\text{fair}}$ increases from 0.00 to 0.20, exposure Jain's index rises monotonically from 0.3793 to 0.6665, booking Jain rises from 0.2823 to 0.6382, workload Jain rises from 0.1874 to 0.5476, and exposure starvation falls from 30.41% to 13.59%. The default configuration ($w_{\text{fair}} = 0.10$) secures 65.25% of the total achievable exposure fairness gain:
$$\frac{0.5667 - 0.3793}{0.6665 - 0.3793} = \frac{0.1874}{0.2872} \approx 65.25\%$$
while maintaining customer travel distance at a compact 2.12 km and higher average rating (4.27). In contrast, higher weights (0.15 and 0.20) increase travel distance to 2.24 km and 2.40 km (+13.2% transit overhead) and slightly reduce top-1 rating to 4.23. In physical artisan services, travel distance imposes real fuel expenses, transit delays, and worker exhaustion. We do not claim that $w_{\text{fair}} = 0.10$ is mathematically optimal; rather, it represents a defensible operational trade-off balancing proximity overhead against distributive equity for municipal artisan cooperatives. Different cooperative federations can configure this weight based on local urban density and transport realities.

---

### H. PostgreSQL Stored Procedure Latency Profiling (RQ5)

| Processing Phase | Mean (ms) | Median (ms) | P95 (ms) | Database Access Mechanism |
| :--- | :---: | :---: | :---: | :--- |
| **1. Candidate Filtering & Join** | 1.15 ms | 1.08 ms | 1.42 ms | Index Scan on `idx_worker_skills_skill_worker` |
| **2. Workload Subquery Aggregation** | 2.85 ms | 2.64 ms | 3.91 ms | Index Scan on `idx_bookings_worker_status_created` |
| **3. Distance & Multi-Criteria Scoring** | 1.02 ms | 0.96 ms | 1.38 ms | In-kernel floating-point Haversine math |
| **4. Sorting & JSONB Serialization** | 0.82 ms | 0.74 ms | 1.15 ms | Quicksort + `jsonb_build_object()` |
| **Total End-to-End RPC Execution** | **5.84 ms** | **5.42 ms** | **7.86 ms** | PostgreSQL PL/pgSQL Stored Procedure Kernel |
*Table V. PostgreSQL stored-procedure execution latency (100 runs across 5 trades).*

Table V decomposes the server-side runtime of `fairmatch_recommend_workers` measured across 100 executions on the production PostgreSQL schema. Total stored procedure execution averages **5.84 ms** (P95 of 7.86 ms), dominated by the cross-worker workload subquery aggregation (2.85 ms). In-memory client scoring takes under 0.01 ms (Table II-B). Both tiers comfortably meet typical interactive mobile UI budgets (< 100 ms).

---

### I. Geographic Demand Clustering Robustness Evaluation (RQ4)

To evaluate algorithmic behavior under non-uniform demand, an empirical benchmark was conducted evaluating Nearest-First, Nearest+Least-Loaded, FairMatch, and Ablation across four spatial scenarios (5 seeds, 1,000 requests each):
- **Scenario A:** Uniform Workers, Uniform Customer Demand (identical to main benchmark).
- **Scenario B:** Clustered Workers (concentrated in two 2.5 km artisan hubs), Uniform Customer Demand.
- **Scenario C:** Uniform Workers, Clustered Customer Demand (75% of customer requests concentrated in a 2 km commercial core).
- **Scenario D:** Clustered Workers, Clustered Customer Demand.

| Scenario & Algorithm | Exp Jain (↑) | Exp Starv (%) | Book Jain (↑) | Workload Jain (↑) | Top-1 Dist |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Scenario A: Uniform / Uniform** | | | | | |
| Nearest-First | 0.772 ± 0.029 | 10.45% | 0.653 ± 0.028 | 0.364 ± 0.027 | 1.42 ± 0.04 km |
| Nearest + Least-Loaded | 0.798 ± 0.028 | 10.45% | 0.740 ± 0.027 | 0.497 ± 0.024 | 1.59 ± 0.04 km |
| FairMatch v1 | **0.567 ± 0.017** | **17.96%** | **0.508 ± 0.017** | **0.403 ± 0.024** | **2.12 ± 0.04 km** |
| Ablation (No Fairness) | 0.379 ± 0.009 | 30.41% | 0.282 ± 0.008 | 0.187 ± 0.011 | 2.38 ± 0.07 km |
| **Scenario B: Clustered Workers / Uniform Demand** | | | | | |
| Nearest-First | 0.654 ± 0.019 | 10.05% | 0.447 ± 0.017 | 0.270 ± 0.022 | 3.26 ± 0.06 km |
| Nearest + Least-Loaded | 0.794 ± 0.014 | 9.52% | 0.718 ± 0.015 | 0.543 ± 0.019 | 3.55 ± 0.07 km |
| FairMatch v1 | **0.507 ± 0.014** | **32.13%** | **0.465 ± 0.017** | **0.410 ± 0.021** | **3.87 ± 0.05 km** |
| Ablation (No Fairness) | 0.268 ± 0.010 | 55.54% | 0.190 ± 0.010 | 0.151 ± 0.016 | 3.94 ± 0.08 km |
| **Scenario C: Uniform Workers / Clustered Demand** | | | | | |
| Nearest-First | 0.214 ± 0.021 | 10.63% | 0.143 ± 0.015 | 0.087 ± 0.016 | 1.40 ± 0.06 km |
| Nearest + Least-Loaded | 0.520 ± 0.022 | 10.45% | 0.480 ± 0.016 | 0.381 ± 0.016 | 2.58 ± 0.08 km |
| FairMatch v1 | **0.456 ± 0.011** | **20.36%** | **0.412 ± 0.013** | **0.322 ± 0.016** | **3.20 ± 0.08 km** |
| Ablation (No Fairness) | 0.163 ± 0.007 | 34.71% | 0.098 ± 0.006 | 0.062 ± 0.006 | 2.39 ± 0.08 km |
| **Scenario D: Clustered Workers / Clustered Demand** | | | | | |
| Nearest-First | 0.285 ± 0.019 | 14.59% | 0.183 ± 0.017 | 0.113 ± 0.016 | 2.35 ± 0.06 km |
| Nearest + Least-Loaded | 0.634 ± 0.019 | 9.60% | 0.587 ± 0.017 | 0.486 ± 0.017 | 3.01 ± 0.08 km |
| FairMatch v1 | **0.474 ± 0.018** | **33.30%** | **0.448 ± 0.013** | **0.409 ± 0.013** | **3.47 ± 0.06 km** |
| Ablation (No Fairness) | 0.167 ± 0.005 | 57.04% | 0.100 ± 0.006 | 0.073 ± 0.007 | 2.98 ± 0.07 km |
*Table VI. Geographic demand clustering robustness (mean ± std dev, 5 seeds, 5,000 requests per scenario).*

**1) Resolution of Scenario A vs. Main Benchmark:** In earlier preliminary draft iterations, decoupled simulation scripts produced minor numerical divergences between the general baseline table and the spatial evaluation. Under the unified multi-seed benchmark harness (`run_multiseed_experiments.js`), Scenario A uses the identical synthetic artisan registry, candidate generation pipeline, and stochastic customer choice model as the main benchmark. Consequently, Scenario A results in Table VI match Table II-A **100% identically across all metrics** (e.g., FairMatch Exposure Jain $0.567 \pm 0.017$, Top-1 Distance $2.12 \pm 0.04\text{ km}$, Workload Jain $0.403 \pm 0.024$; Nearest-First Exposure Jain $0.772 \pm 0.029$, Workload Jain $0.364 \pm 0.027$).

**2) Scenario B Evaluation (Clustered Artisans, Uniform Municipal Demand):** In Scenario B, artisans are geographically clustered into two artisan craft quarters (2.5 km radius) while customer demand remains uniformly dispersed across the municipality. In this setting, Nearest-First yields an Exposure Jain of $0.654 \pm 0.019$ and low Exposure Starvation (10.05%), but exhibits severe physical workload imbalance (Workload Jain $0.270 \pm 0.022$; raw mean 0.2695, std 0.0219) because workers located closest to high-density boundaries absorb the brunt of incoming requests. FairMatch sustains a Workload Jain of **$0.410 \pm 0.021$** (+51.9% higher than Nearest-First), shedding overload from hub artisans who would otherwise suffer exhaustion, at the cost of higher exposure starvation (32.13%) and moderately increased transit distance (3.87 vs 3.26 km).

**3) Scenario C Evaluation (Commercial Core Concentration):** Under Scenario C, where 75% of customer requests originate within a 2 km commercial core, Nearest-First suffers severe fairness degradation: Exposure Jain falls from 0.772 to 0.214 (-72.3%), Booking Jain falls to 0.143, and Workload Jain plummets to 0.087 (acute artisan fatigue and monopoly, with the top decile absorbing 60.89% of all exposure). FairMatch's saturation penalty dynamically redirects demand away from saturated central artisans once active commitments accumulate, distributing opportunities to capable neighboring artisans and sustaining an Exposure Jain of **0.456** (+113% over Nearest-First), a Booking Jain of **0.412** (+188%), and a Workload Jain of **0.322** (+270%). While Nearest+Least-Loaded achieves an Exposure Jain of 0.520 and Workload Jain of 0.381, it lacks quality controls, delivering lower service ratings (4.07 vs 4.27) and unverified cold-start exposure.

**4) Scenario D Evaluation (Compound Spatial Polarization):** In Scenario D, both artisans and customer demands are clustered. Nearest-First exhibits an Exposure Jain of $0.285 \pm 0.019$ and a Workload Jain of $0.113 \pm 0.016$, with the top-decile workers capturing $50.30 \pm 1.40\%$ of all platform exposure (recorded in benchmark logs, compared to $69.20 \pm 3.11\%$ for Ablation). In contrast, FairMatch sustains an Exposure Jain of **$0.474 \pm 0.018$** (raw mean 0.4735, std 0.0183), a Workload Jain of **$0.409 \pm 0.013$**, and restricts top-decile exposure share to $29.41 \pm 1.07\%$, demonstrating that the multi-criteria feedback mechanism maintains distributive equity even under compound spatial polarization.

---

## VI. Implementation and Reproducibility

To ensure independent verification, all benchmark code, raw experimental outputs, and migration scripts are openly accessible:
- **Codebase Repository:** [https://github.com/DEVESHAMBEKAR/ShramSetu](https://github.com/DEVESHAMBEKAR/ShramSetu) (Commit `f7bce061338e94ef4f350f4deb90acc9dc17b2b3`).
- **Database Migrations:** `supabase/migrations/013_fairmatch_engine.sql` and `029_booking_payment_and_dispatch.sql`.
- **Client Scoring Engine:** `app/lib/core/services/fairmatch_engine.dart` and `app/lib/core/models/fairmatch_models.dart`.
- **Unit Test Suite:** `app/test/fairmatch_test.dart` (8 test suites, 32 assertions covering feature extraction, tie-breaking, and graceful fallback).
- **Experimental Benchmark Script:** `run_multiseed_experiments.js` executing the unified baseline, ablation, sensitivity, and spatial clustering evaluations.
- **Raw Experimental Outputs:** `benchmark_results/` containing raw JSON outputs for all five seeds and `execution_run.log`.
- **Benchmark Environment:** 12th Gen Intel Core i5-12450H CPU (12 cores), 16 GB RAM, Node.js v22.22.2, Windows 11 Enterprise x64.

---

## VII. Threats to Validity and Limitations

Several validity boundaries must be acknowledged:
1. **Synthetic Profiles and Assumed Behavior:** The experimental benchmark utilizes synthetically generated artisan profiles and customer requests. While spatial coordinates and ratings reflect municipal distributions, actual customer choice behavior may exhibit brand affinity, direct referrals, or price bargaining not captured by the rank cascade.
2. **Logarithmic Attention Discount:** Position discount is modeled via logarithmic decay; actual consumer attention on mobile smartphone screens may decay more steeply.
3. **Binary Skill Predicates:** In the current prototype, skill verification and availability act as invariant eligibility constraints; future work will introduce graded multi-skill trade levels to enable discriminative skill scoring.
4. **Timestamp Semantics in Saturation Term:** The current database saturation term queries `created_at` rather than true completion timestamps (measuring bookings created in the trailing 7 days that have reached completed status); future revisions will migrate to `completed_at` once mobile completion telemetry is universally deployed.
5. **Absence of Cognitive User Studies:** The rule-based explanation badges have not yet been evaluated through formal human-computer interaction user studies with actual artisan workers and consumers.
6. **Comparison Scope:** FairMatch focuses on lightweight, per-request scoring executable within standard relational databases. Global multi-period optimization algorithms (e.g., ILP batch dispatch) were not evaluated in this benchmark and represent an orthogonal research direction.

---

## VIII. Conclusion

This paper formalized, implemented, and empirically evaluated **FairMatch**, an explainable and fairness-aware worker recommendation framework for cooperative service marketplaces. By combining craft qualification, geodesic distance, cold-start reputation correction, artisan experience, and an inverse-workload fairness metric into a deterministic multi-criteria model, FairMatch mitigates the extreme winner-take-all monopolization typical of commercial gig platforms. Multi-seed empirical benchmarks demonstrate that FairMatch improves Jain's fairness index of exposure by +49.6% over ablated models, cuts worker starvation by over 75% compared to reputation-only ranking, and provides an empirical entry pathway for unreviewed newcomers (11.09% top-5 share), while preserving tight 2.12 km proximity and sub-millisecond scoring efficiency. Crucially, empirical evaluations under clustered urban demand confirm that while Nearest-First suffers severe fairness degradation (Jain falling to 0.214), FairMatch maintains robust distributive equity across exposure (0.456), bookings (0.412), and physical workload (0.322). Future research will investigate dynamic adaptive weight scheduling based on real-time supply-demand elasticities across cooperative federations.

---

### Acknowledgment
The author gratefully acknowledges the artisan collectives, municipal cooperative federations, and open-source contributors of Project ShramSetu for their operational domain insights, testing feedback, and commitment to equitable digital labor platforms.

**IEEE Generative AI Policy Disclosure:** During the preparation of this work, the author used generative AI assistance (Google DeepMind Antigravity/Gemini) for manuscript formatting, LaTeX/KaTeX equation verification, and code syntax checks. All simulation architectures, database stored procedures, algorithmic formulations, experimental designs, and empirical analyses were developed, executed, verified, and validated by the author, who takes full responsibility for the contents of the publication.

---

## References

1. A. Singh and T. Joachims, “Fairness of exposure in rankings,” in *Proc. 24th ACM SIGKDD Int. Conf. Knowl. Discov. Data Mining*, London, U.K., 2018, pp. 2219–2228, doi: 10.1145/3219819.3220088.
2. M. Zehlike, K. Yang, and J. Stoyanovich, “Fairness in ranking, Part II: Learning-to-rank and recommender systems,” *ACM Comput. Surv.*, vol. 55, no. 6, Art. no. 117, pp. 1–41, Dec. 2022, doi: 10.1145/3533380.
3. Y. Deldjoo et al., “Fairness in recommender systems: Research landscape and future directions,” *User Model. User-Adapt. Interact.*, vol. 34, pp. 59–108, 2024, doi: 10.1007/s11257-023-09364-z.
4. D. Monti, G. Rizzo, and M. Morisio, “A systematic literature review of multicriteria recommender systems,” *Artif. Intell. Rev.*, vol. 54, pp. 427–468, 2021, doi: 10.1007/s10462-020-09851-4.
5. D. Jin, L. Wang, H. Zhang, Y. Zheng, W. Ding, F. Xia, and S. Pan, “A survey on fairness-aware recommender systems,” *Inf. Fusion*, vol. 100, Art. no. 101906, Dec. 2023, doi: 10.1016/j.inffus.2023.101906.
6. A. J. Biega, K. P. Gummadi, and G. Weikum, “Equity of attention: Amortizing individual fairness in rankings,” in *Proc. 41st Int. ACM SIGIR Conf. Res. Dev. Inf. Retr.*, Ann Arbor, MI, USA, 2018, pp. 405–414, doi: 10.1145/3209978.3210063.
7. R. Burke, “Multisided fairness for recommendation,” in *Proc. Workshop Fairness, Accountability, Transparency Mach. Learn. (FAT/ML)*, Halifax, NS, Canada, Aug. 2017. arXiv: 1707.00093.
8. H. Abdollahpouri, G. Adomavicius, R. Burke, I. Guy, D. Jannach, T. Kamishima, J. Krasnodebski, and L. Pizzato, “Multistakeholder recommendation: Survey and research directions,” *User Model. User-Adapt. Interact.*, vol. 30, no. 4, pp. 587–627, 2020, doi: 10.1007/s11257-019-09256-1.
9. A. Hannák, C. Wagner, D. Garcia, A. Mislove, M. Strohmaier, and C. Wilson, “Bias in online freelance marketplaces: Evidence from TaskRabbit and Fiverr,” in *Proc. ACM Conf. Comput. Support. Coop. Work Soc. Comput. (CSCW)*, Portland, OR, USA, 2017, pp. 1914–1933, doi: 10.1145/2998181.2998327.
10. L. Chen, A. Mislove, and C. Wilson, “Peeking beneath the hood of Uber: Exploring taxi ride, pricing, and dynamic dispatch algorithms,” in *Proc. ACM Internet Meas. Conf. (IMC)*, Tokyo, Japan, 2015, pp. 495–508, doi: 10.1145/2815675.2815681.
11. G. Adomavicius and A. Tuzhilin, “Toward the next generation of recommender systems: A survey of the state-of-the-art and possible extensions,” *IEEE Trans. Knowl. Data Eng.*, vol. 17, no. 6, pp. 734–749, June 2005, doi: 10.1109/TKDE.2005.99.
12. R. Jain, D.-M. Chiu, and W. R. Hawe, “A quantitative measure of fairness and discrimination for resource allocation in shared computer systems,” *DEC Res. Rep. TR-301*, Digital Equipment Corp., Hudson, MA, USA, Sept. 1984.
13. P. Craswell, O. Zoeter, M. Taylor, and B. Ramsey, “An experimental comparison of click position-bias models,” in *Proc. Int. Conf. Web Search Data Mining (WSDM)*, Stanford, CA, USA, 2008, pp. 87–94, doi: 10.1145/1341531.1341545.
14. M. Zehlike, F. Bonchi, C. Castillo, S. Hajian, and K. Megahed, “FA*IR: A fair top-k ranking algorithm,” in *Proc. ACM CIKM Conf. Inf. Knowl. Manage.*, Singapore, 2017, pp. 1569–1578, doi: 10.1145/3132847.3132938.
15. V. Do, S. Corbett-Davies, N. Foti, and E. Fox, “Two-sided fairness in repeated matching: Online allocation with guarantees,” in *Proc. 38th Int. Conf. Mach. Learn. (ICML)*, 2021, pp. 2784–2794.
16. M. Möhlmann and L. Zalmanson, “Hands on the wheel: Navigating algorithmic management and worker autonomy,” in *Proc. Int. Conf. Inf. Syst. (ICIS)*, Seoul, South Korea, 2017, pp. 1–18.
17. M. K. Lee, D. Kusbit, E. Metsky, and L. Dabbish, “Working with machines: The impact of algorithmic and data-driven management on human workers,” in *Proc. 33rd Annu. ACM Conf. Hum. Factors Comput. Syst. (CHI)*, Seoul, South Korea, 2015, pp. 1603–1612, doi: 10.1145/2702123.2702548.
18. G. Adomavicius and Y. Kwon, “Multi-criteria recommender systems,” in *Recommender Systems Handbook*, F. Ricci, L. Rokach, B. Shapira, and P. B. Kantor, Eds. Boston, MA: Springer, 2011, pp. 769–803, doi: 10.1007/978-0-387-85820-3_24.
19. P. Mavridis, D. Gross-Amblard, and Z. Miklós, “Using hierarchical skills for optimized task assignment in crowdsourcing,” in *Proc. 25th Int. Conf. World Wide Web (WWW)*, Montreal, Canada, 2016, pp. 843–853, doi: 10.1145/2872427.2883088.
20. D. E. Difallah, M. Catasta, G. Demartini, P. G. Ipeirotis, and P. Cudré-Mauroux, “The dynamics of micro-task crowdsourcing: The case of Amazon MTurk,” in *Proc. 24th Int. Conf. World Wide Web (WWW)*, Florence, Italy, 2015, pp. 238–248, doi: 10.1145/2736277.2741685.
