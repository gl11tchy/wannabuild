# Contributing to WannaBuild

First off, thanks for considering contributing to WannaBuild! 🎉

## How Can I Contribute?

### Reporting Bugs

- Check if the bug has already been reported in [Issues](https://github.com/gl11tchy/wannabuild/issues)
- If not, create a new issue with a clear title and description
- Include steps to reproduce, expected behavior, and actual behavior

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the feature and why it would be useful
- Be open to discussion about implementation

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added a skill, ensure it follows the existing structure
3. Update documentation if needed
4. Test your changes
5. Submit the PR!

## Skill Development Guidelines

### Structure

Each skill should have:
```
skills/your-skill/
├── SKILL.md          # Main skill definition
└── references/       # Optional supporting docs
    └── *.md
```

### SKILL.md Format

```markdown
---
name: your-skill-name
description: "Brief description for skill discovery"
---

# Skill Name

[Full documentation]
```

### Best Practices

- **Single responsibility**: Each skill does one thing well
- **Clear triggers**: Document when the skill should activate
- **Artifacts**: Define what the skill produces
- **Handoffs**: Explain how it connects to other phases

## Code of Conduct

Be kind. We're all here to build cool stuff.

## Questions?

Open an issue or start a discussion. We're happy to help!
