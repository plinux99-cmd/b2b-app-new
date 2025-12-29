================================================================================
                       DOCUMENTATION INDEX
                  All Infrastructure Documentation Files
================================================================================

PROJECT: AeroWise CDN + API Gateway + EKS Infrastructure
CREATED: December 28, 2025
LOCATION: /Users/pramod.kumarnavikenz.com/test9-few-thing-left/

================================================================================
DOCUMENTATION FILES
================================================================================

1. QUICK_START.txt (194 lines, 11KB)
   ──────────────────────────────────
   📌 START HERE for new deployments!
   
   Contains:
   ✓ 4-step deployment checklist
   ✓ 8 verification tests (copy/paste ready)
   ✓ Expected outputs for each test
   ✓ API endpoints reference
   ✓ Protected/Public routes list
   ✓ Common issues & solutions
   ✓ Security notes
   
   Use when: First-time deployment, quick checks, testing
   
   Key sections:
   - STEP 1: terraform apply
   - STEP 2: Upload index.html (MANUAL!)
   - STEP 3: Invalidate CloudFront
   - STEP 4: Run 8 verification tests

────────────────────────────────────────────────────────────────────────────────

2. SANITY_CHECKS.txt (503 lines, 28KB)
   ───────────────────────────────────
   📌 COMPREHENSIVE reference for all validation commands
   
   Contains 12 sections:
   ✓ Section 1:  Terraform validation (5 commands)
   ✓ Section 2:  S3 & static content (4 commands)
   ✓ Section 3:  API Gateway routes (3 commands)
   ✓ Section 4:  Lambda authorizer (2 commands)
   ✓ Section 5:  EKS cluster (4 commands)
   ✓ Section 6:  Load balancer (3 commands)
   ✓ Section 7:  CloudFront CDN (2 commands)
   ✓ Section 8:  End-to-end testing (5 commands)
   ✓ Section 9:  Quick health check script
   ✓ Section 10: Post-apply checklist
   ✓ Section 11: Troubleshooting guide
   ✓ Section 12: Summary & key points
   
   Total: 50+ commands with expected outputs
   
   Use when: Detailed validation, troubleshooting, monitoring
   
   Best for:
   - Understanding each component
   - Full infrastructure checks
   - Debugging issues
   - Long-term monitoring
   - Copy/paste any command needed

────────────────────────────────────────────────────────────────────────────────

3. .github/copilot-instructions.md
   ────────────────────────────────
   📌 Architecture and project documentation
   
   Contains:
   ✓ Layout & architecture overview
   ✓ Core workflows (Terraform, Kubernetes)
   ✓ Deployment strategy
   ✓ Terraform modules reference
   ✓ CDN WAF validation checklist
   ✓ Safety guidelines
   
   Use when: Understanding project structure, architecture review
   
   Key topics:
   - Infrastructure layout
   - Terraform commands
   - Kubernetes integration
   - API Gateway setup
   - WAF configuration

════════════════════════════════════════════════════════════════════════════════
QUICK DECISION TREE
════════════════════════════════════════════════════════════════════════════════

I need to...                         → Read this file
─────────────────────────────────────────────────────────
Deploy infrastructure              → QUICK_START.txt (Step 1-4)
Upload static content              → QUICK_START.txt (Step 2)
Test after deployment              → QUICK_START.txt (Step 4)
Troubleshoot issues                → SANITY_CHECKS.txt (Section 11)
Verify health regularly            → SANITY_CHECKS.txt (Section 9)
Check specific component           → SANITY_CHECKS.txt (Sections 1-7)
Understand architecture            → copilot-instructions.md
Run end-to-end tests              → SANITY_CHECKS.txt (Section 8)
Validate Terraform config          → SANITY_CHECKS.txt (Section 1)
Check S3 & CloudFront             → SANITY_CHECKS.txt (Section 2-7)

════════════════════════════════════════════════════════════════════════════════
TYPICAL WORKFLOW
════════════════════════════════════════════════════════════════════════════════

SCENARIO 1: First-Time Deployment
──────────────────────────────────
1. Read: QUICK_START.txt (top section)
2. Run: terraform apply (QUICK_START.txt Step 1)
3. Run: aws s3 cp ... (QUICK_START.txt Step 2)
4. Run: aws cloudfront create-invalidation (QUICK_START.txt Step 3)
5. Run: All 8 tests (QUICK_START.txt Step 4)
6. Check: Expected Results section

TIME: 20-30 minutes

────────────────────────────────────────────────────────────────────────────────

SCENARIO 2: Troubleshooting an Issue
────────────────────────────────────
1. Check: QUICK_START.txt "Common Issues & Solutions"
2. Read: SANITY_CHECKS.txt (Section 11 - Troubleshooting)
3. Copy: Relevant command from appropriate section
4. Run: Command and compare with "EXPECTED OUTPUT"
5. Fix: Based on troubleshooting recommendations

TIME: 10-20 minutes

────────────────────────────────────────────────────────────────────────────────

SCENARIO 3: Regular Health Monitoring
─────────────────────────────────────
1. Run: Quick health check (SANITY_CHECKS.txt Section 9)
2. Review: Results against expected values
3. If issues: Jump to Scenario 2 (Troubleshooting)
4. Document: Any changes or issues found

TIME: 5 minutes

════════════════════════════════════════════════════════════════════════════════
CRITICAL INFORMATION
════════════════════════════════════════════════════════════════════════════════

⚠️  IMPORTANT NOTES:

1. terraform apply does NOT upload index.html to S3
   → You MUST run aws s3 cp manually (see QUICK_START.txt Step 2)

2. terraform apply does NOT invalidate CloudFront cache
   → You MUST run aws cloudfront create-invalidation (QUICK_START.txt Step 3)

3. Protected routes require Authorization header
   → /assetservice, /flightservice, /paxservice, /notificationservice

4. Public routes do NOT require authorization
   → /authservice, /app-version/check, /data, /broadcast, /client-login

5. All endpoints are served through CloudFront CDN
   → Both static content and API responses are cached

════════════════════════════════════════════════════════════════════════════════
KEY COMMANDS AT A GLANCE
════════════════════════════════════════════════════════════════════════════════

Deploy:
────────
cd terraform/infra && terraform apply tfplan

Upload Static Content (MANUAL!):
────────────────────────────────
aws s3 cp terraform/edge/static/index.html \
  s3://aerowise-t1-edge-static-prod/index.html \
  --content-type "text/html; charset=utf-8" \
  --cache-control "max-age=3600"

Invalidate Cache:
─────────────────
aws cloudfront create-invalidation --distribution-id E1XM2A32MZPP1F --paths "/*"

Quick Health Check:
───────────────────
See SANITY_CHECKS.txt Section 9

Test Public Route:
──────────────────
curl -s https://0rjx2pu6e9.execute-api.us-east-1.amazonaws.com/app-version/check

Test Protected Route (no auth):
───────────────────────────────
curl -s https://0rjx2pu6e9.execute-api.us-east-1.amazonaws.com/assetservice

Test CloudFront Static:
──────────────────────
curl -s --compressed https://d2du4fpuifrh5y.cloudfront.net/

════════════════════════════════════════════════════════════════════════════════
API ENDPOINTS
════════════════════════════════════════════════════════════════════════════════

API Gateway (Direct):
  https://0rjx2pu6e9.execute-api.us-east-1.amazonaws.com

CloudFront CDN (Recommended):
  https://d2du4fpuifrh5y.cloudfront.net

PROTECTED ROUTES (require Authorization header):
  • /assetservice
  • /flightservice
  • /paxservice
  • /notificationservice

PUBLIC ROUTES (no authorization needed):
  • /app-version/check
  • /authservice
  • /data
  • /broadcast
  • /client-login

════════════════════════════════════════════════════════════════════════════════
FILE LOCATIONS
════════════════════════════════════════════════════════════════════════════════

Documentation:
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/QUICK_START.txt
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/SANITY_CHECKS.txt
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/.github/copilot-instructions.md

Terraform:
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/terraform/infra/
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/terraform/modules/

Static Content:
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/terraform/edge/static/index.html

Kubernetes:
  /Users/pramod.kumarnavikenz.com/test9-few-thing-left/kubernetes/

════════════════════════════════════════════════════════════════════════════════
GETTING HELP
════════════════════════════════════════════════════════════════════════════════

For quick answers:
  → Check QUICK_START.txt "Common Issues & Solutions"

For detailed commands:
  → Use SANITY_CHECKS.txt (find relevant section by component)

For architecture:
  → Read copilot-instructions.md

For specific issues:
  → Search SANITY_CHECKS.txt Section 11 (Troubleshooting)

════════════════════════════════════════════════════════════════════════════════
SUMMARY
════════════════════════════════════════════════════════════════════════════════

✅ QUICK_START.txt
   → Fast deployment guide + verification tests
   → Use for: New deployments, quick checks

✅ SANITY_CHECKS.txt
   → Comprehensive validation reference + 50+ commands
   → Use for: Detailed testing, troubleshooting, monitoring

✅ copilot-instructions.md
   → Architecture and project documentation
   → Use for: Understanding structure, design decisions

════════════════════════════════════════════════════════════════════════════════

All files are production-ready and can be used immediately!

Happy deploying! 🚀

================================================================================
