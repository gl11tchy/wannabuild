<div align="center">

# 🏗️ WannaBuild

**Multi-agent software development framework.**

*Talk naturally, ship professionally.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

[Getting Started](#getting-started) · [Philosophy](#philosophy) · [Phases](#the-6-phases) · [Installation](#installation) · [Contributing](#contributing)

</div>

---

## What is WannaBuild?

WannaBuild is a conversational development framework that guides you from idea to shipped code using specialized AI agents at each phase.

**Instead of:**
```
/framework:start-planning --template=prd --verbose
```

**Just say:**
```
I wanna build a user authentication system with OAuth
```

And WannaBuild takes it from there.

---

## Philosophy

### 1. Conversation over commands
No syntax to memorize. Talk like a human, build like a pro.

### 2. Specialists over generalists
Each phase deploys agents with deep expertise in one thing. The code review phase alone runs **5 parallel specialists**:
- Plan Verifier
- Security Auditor
- Best Practices Checker
- System Architect
- Code Simplifier

### 3. Quality loops, not quality gates
Code doesn't just get reviewed — it gets **iterated until perfect**. The implement↔review loop continues until all 5 specialists vote to approve.

### 4. Flexibility over dogma
Best practices are recommended, not enforced with an iron fist. You're the developer; WannaBuild is your team.

### 5. Built for indie hackers
Not enterprise methodology shrunk down. Built ground-up for solo developers and small teams who need to ship.

---

## The 6 Phases

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  💭 BRAINSTORM ──→ 📋 PLAN ──→ 🔨 IMPLEMENT ◄──┐                │
│                                      │         │                │
│                                      ▼         │                │
│                               🔍 REVIEW ───────┘                │
│                                      │     (loop until          │
│                                      │      5/5 approve)        │
│                                      ▼                          │
│                               🚀 SHIP ──→ 📚 DOCUMENT           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1. 💭 Brainstorm
*"What do you wanna build?"*

- Analyzes your existing codebase
- Asks clarifying questions naturally
- Explores scope and alternatives
- Produces a lightweight spec (not a 50-page PRD)

### 2. 📋 Plan
*"Here's how we'll build it"*

- Breaks work into concrete tasks
- Identifies dependencies and risks
- Creates just enough structure to execute
- Optional: spawns specialist agents for scope analysis

### 3. 🔨 Implement
*"Let's build it"*

- Executes tasks from the plan
- Writes tests as it goes
- Commits incrementally
- Accepts feedback from review loops

### 4. 🔍 Review
*"Let's make sure it's solid"*

Deploys **5 specialist agents in parallel**:

| Agent | Focus |
|-------|-------|
| Plan Verifier | Does implementation match requirements? |
| Security Auditor | Any vulnerabilities or exposed secrets? |
| Best Practices | Using modern patterns? Deprecated APIs? |
| Architect | Sound system design? Good boundaries? |
| Code Simplifier | DRY? Readable? Refactoring opportunities? |

**The Quality Loop:** If any agent finds issues, feedback goes back to Implement. The loop continues until **unanimous approval** from all 5 agents.

### 5. 🚀 Ship
*"Let's get it merged"*

- Prepares branch for merge
- Creates PR with clear description
- Runs final verification
- Handles merge conflicts

### 6. 📚 Document
*"Let's write it up"*

- Updates README if needed
- Adds/updates API documentation
- Updates changelog
- Documents architectural decisions

---

## Installation

### For Claude Code

```bash
# Clone the repo
git clone https://github.com/gl11tchy/wannabuild.git

# Copy skills to your workspace
cp -r wannabuild/skills/* ~/.claude/skills/
```

### For Clawdbot

```bash
# Clone into your skills directory
cd ~/clawd/skills
git clone https://github.com/gl11tchy/wannabuild.git wannabuild-framework

# Or symlink individual skills
ln -s wannabuild-framework/skills/* .
```

### Manual Installation

Copy the contents of `/skills` into wherever your AI coding agent looks for skills/instructions.

---

## Usage

### Start Fresh
```
I wanna build [describe your feature]
```

### Jump to a Phase
```
Let's plan [feature] - I already know what I want
```

```
Review the code in [path]
```

```
Help me document [what was built]
```

### Skip Phases
Not everything needs all 6 phases. Quick bug fix? Jump straight to implement. Docs-only change? Skip review.

---

## What Makes WannaBuild Different?

| Aspect | Traditional Frameworks | WannaBuild |
|--------|----------------------|------------|
| Entry point | Commands & templates | Natural conversation |
| Review | 1-2 checks, then done | 5 specialists, iterate until approved |
| Philosophy | Process compliance | Ship quality code |
| Artifacts | Heavy documentation | Minimal viable specs |
| Target user | Enterprise teams | Indie hackers & small teams |

---

## Project Structure

```
wannabuild/
├── skills/
│   ├── wannabuild/              # Orchestrator
│   │   └── SKILL.md
│   ├── wannabuild-brainstorm/   # Phase 1
│   │   └── SKILL.md
│   ├── wannabuild-plan/         # Phase 2
│   │   └── SKILL.md
│   ├── wannabuild-implement/    # Phase 3
│   │   └── SKILL.md
│   ├── elite-code-review/       # Phase 4 (5 agents)
│   │   └── SKILL.md
│   ├── wannabuild-ship/         # Phase 5
│   │   └── SKILL.md
│   └── wannabuild-document/     # Phase 6
│       └── SKILL.md
├── docs/
│   └── philosophy.md
├── examples/
│   └── ...
└── README.md
```

---

## Contributing

WannaBuild is open source and contributions are welcome!

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Inspired by the growing ecosystem of AI coding tools
- Built for the indie hacker community
- Special thanks to everyone who ships

---

<div align="center">

**What do you wanna build?**

[Get Started](#installation) · [Report Bug](https://github.com/gl11tchy/wannabuild/issues) · [Request Feature](https://github.com/gl11tchy/wannabuild/issues)

</div>
