# PyDataPro — Complete Deployment & Launch Guide

## 1. Local Setup (15 minutes)

```bash
# Clone / init project
npx create-next-app@latest pydatapro --typescript --tailwind --app
cd pydatapro

# Install all dependencies
npm install @supabase/supabase-js @supabase/ssr \
  @anthropic-ai/sdk @monaco-editor/react \
  razorpay resend clsx tailwind-merge

# Copy your source files into src/
# (All files from this bundle go here)

# Set up env
cp .env.example .env.local
# Fill in your keys (see step 2-5 below)

npm run dev
```

---

## 2. Supabase Setup (10 minutes)

1. Go to https://supabase.com → New project
2. Choose region: **Mumbai (ap-south-1)** — closest to Indian users
3. Project name: `pydatapro`
4. Copy the **URL** and **anon key** → `.env.local`
5. Go to **SQL Editor** → paste contents of `supabase/schema.sql` → Run
6. Go to **Authentication → Providers**:
   - Enable **Google** (add OAuth client from Google Cloud Console)
   - Enable **Email** (confirm emails on)
7. Go to **Authentication → URL Configuration**:
   - Site URL: `https://pydatapro.in`
   - Redirect URLs: `https://pydatapro.in/dashboard`

---

## 3. Razorpay Setup (10 minutes)

1. Sign up at https://razorpay.com
2. Complete KYC (PAN + bank account) — takes 1-2 days
3. Dashboard → Settings → API Keys → Generate live keys
4. Copy Key ID + Secret → `.env.local`
5. Webhooks → Add webhook:
   - URL: `https://pydatapro.in/api/payments/webhook`
   - Events: `payment.captured`, `payment.failed`
   - Copy webhook secret → `RAZORPAY_WEBHOOK_SECRET`

---

## 4. Anthropic API Setup (5 minutes)

1. https://console.anthropic.com → API Keys → Create key
2. Add to `.env.local` as `ANTHROPIC_API_KEY`
3. Set spend limit: ₹2,000/month initially
4. The hint API uses `claude-sonnet-4-20250514` with max 200 tokens per hint
   — very cheap, ~₹0.02 per hint

---

## 5. Code Execution (Judge0)

**Option A — RapidAPI (easiest, 100 free calls/day):**
1. https://rapidapi.com/judge0-official/api/judge0-ce
2. Subscribe to Basic (free)
3. Copy API key → `JUDGE0_API_KEY`

**Option B — Self-host on Railway (recommended for scale):**
```bash
# Deploy Judge0 CE via Railway template
# https://railway.app/template/judge0
# Free $5 credit/month — runs ~100k submissions
```

---

## 6. Vercel Deployment (5 minutes)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Add environment variables
vercel env add NEXT_PUBLIC_SUPABASE_URL
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
# ... (add all variables from .env.example)

# Production deploy
vercel --prod
```

**Or via GitHub:**
1. Push to GitHub
2. https://vercel.com → Import repository
3. Add all env variables in Vercel dashboard
4. Deploy

**Custom domain:**
1. Vercel → Domains → Add `pydatapro.in`
2. Update DNS at your registrar (GoDaddy / Namecheap / Cloudflare)

---

## 7. Make.com Email Automation (20 minutes)

1. Sign up at https://make.com (free: 1,000 ops/month)
2. Create new scenario
3. Import `make-automation/automation-blueprint.json`
4. Connect Supabase module (add project URL + service key)
5. Connect Gmail or Resend module
6. Test each scenario → Activate

**Resend setup (better than Gmail for transactional):**
1. https://resend.com → Free: 3,000 emails/month
2. Add domain `pydatapro.in` → verify DNS
3. API key → `RESEND_API_KEY`

---

## 8. SEO Setup

```bash
# next-sitemap generates sitemap.xml automatically
npm install next-sitemap

# next-sitemap.config.js
module.exports = {
  siteUrl: 'https://pydatapro.in',
  generateRobotsTxt: true,
  exclude: ['/dashboard', '/api/*'],
}

# Add to package.json scripts:
"postbuild": "next-sitemap"
```

**Blog for SEO:**
- Write 2 articles/week targeting keywords
- Priority topics: "Python interview questions for data scientists", 
  "Pandas exercises with solutions", "NumPy tutorial for beginners"
- Submit sitemap to Google Search Console

---

## 9. Post-Launch Checklist

- [ ] Test signup → dashboard flow
- [ ] Test Razorpay payment (use test mode first)
- [ ] Verify webhook fires on payment
- [ ] Test AI hint (solve a problem, press TAB)
- [ ] Test typing challenge saves session
- [ ] Welcome email triggers on signup
- [ ] Mobile responsive check (Chrome DevTools)
- [ ] Page speed > 90 (Vercel + Next.js should nail this)
- [ ] Submit to Google Search Console
- [ ] Add to Product Hunt (schedule for Tuesday 12:01 AM PST)

---

## 10. Growth Playbook (Month 1-3)

### Week 1-2: Foundation
- Post 3 Python tips/day on Twitter + LinkedIn
- Share 1 problem walkthrough on YouTube Shorts
- Join 10 Data Science Discord/Telegram groups
- DM 50 engineering college students

### Week 3-4: Content SEO
- Publish "Top 50 Python Interview Questions (with solutions)" — target 90K/mo keyword
- Guest post on Medium/Hashnode/Dev.to
- Submit to IndiaHacks, DataHack forums

### Month 2: Virality
- Launch referral system — each share = 1 week free
- "60-day challenge" — post daily on LinkedIn with #PyDataPro
- Partner with 2-3 YouTube data science creators (free yearly plan for promotion)

### Month 3: Scale
- College campus ambassador program (5 students/college, free yearly plan)
- Launch affiliate program: 30% commission
- Add certificate feature (₹199 standalone, drives upgrades)
- Run "Python Interview Bootcamp" live cohort (₹999, 100 seats)

---

## Monthly Revenue Projections

| Month | Free Users | Paid Users | Avg Plan | MRR      |
|-------|-----------|------------|----------|----------|
| 1     | 500       | 30         | ₹299     | ₹9,000   |
| 2     | 1,500     | 120        | ₹299     | ₹36,000  |
| 3     | 3,000     | 280        | ₹320     | ₹90,000  |
| 4     | 5,000     | 500        | ₹340     | ₹1,70,000|
| 5     | 8,000     | 800        | ₹350     | ₹2,80,000|
| 6     | 12,000    | 1,200      | ₹360     | ₹4,32,000|

**Path to ₹8L/month:** 2,200+ paid users at avg ₹360 plan value.
Achievable by month 8-10 with consistent content + referrals.

---

## Tech Stack Summary

| Layer       | Tool              | Cost              |
|-------------|-------------------|-------------------|
| Frontend    | Next.js 14        | Free              |
| Hosting     | Vercel            | Free → $20/mo     |
| Auth + DB   | Supabase          | Free → $25/mo     |
| Payments    | Razorpay          | 2% per txn        |
| AI hints    | Anthropic Claude  | ~₹500/mo @ scale  |
| Code runner | Judge0 / Railway  | Free → $5/mo      |
| Email       | Resend            | Free → $20/mo     |
| Automation  | Make.com          | Free → $9/mo      |
| **Total**   |                   | **~₹2,000/mo**    |

Gross margin at ₹8L MRR: **~97%** (SaaS economics 🚀)
