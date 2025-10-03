# Contributing to CerberusGo

Thank you for considering contributing to CerberusGo! This document provides guidelines and instructions for contributing.

## Ways to Contribute

- 🐛 **Bug Reports**: Report bugs via GitHub Issues
- ✨ **Feature Requests**: Suggest new features or improvements
- 📖 **Documentation**: Improve or add documentation
- 💻 **Code**: Submit bug fixes or new features
- 🧪 **Testing**: Test on different hardware configurations

## Getting Started

### Prerequisites

- Raspberry Pi 3 Model B (or compatible)
- Adafruit PiTFT 3.5" Resistive Touchscreen
- Basic knowledge of Python and Linux
- GitHub account

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/cerberusgo.git
   cd cerberusgo
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes**
   - Follow the coding style (see below)
   - Test your changes thoroughly
   - Update documentation if needed

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**
   - Go to your fork on GitHub
   - Click "Pull Request"
   - Describe your changes clearly

## Coding Standards

### Python Style

- Follow [PEP 8](https://pep8.org/) style guide
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 100 characters (when reasonable)
- Use meaningful variable and function names
- Add docstrings to functions and classes

Example:
```python
def fetch_weather(latitude, longitude):
    """
    Fetch weather data from Open-Meteo API.
    
    Args:
        latitude (float): Location latitude
        longitude (float): Location longitude
        
    Returns:
        dict: Weather data or None if failed
    """
    # Implementation here
    pass
```

### Bash/Shell Scripts

- Use `#!/bin/bash` shebang
- Include comments for complex operations
- Use meaningful variable names in UPPER_CASE
- Check return codes of important commands

### PowerShell Scripts

- Use approved verbs (Get-, Set-, New-, etc.)
- Include comment-based help
- Use proper error handling

## Documentation

### Adding Documentation

- Use Markdown format
- Include code examples
- Add screenshots if helpful
- Keep language clear and concise

### Documentation Structure

```
docs/
├── hardware/      # Hardware specifications
├── setup/         # Installation guides
└── guides/        # Usage and troubleshooting guides
```

## Testing

### Before Submitting

1. **Test on actual hardware**
   - Boot test (does it start automatically?)
   - Display test (is output correct?)
   - Weather test (does API work?)
   - Service test (systemd service working?)

2. **Check for errors**
   ```bash
   # Check Python syntax
   python3 -m py_compile src/clock_weather_fbi.py
   
   # Check service logs
   sudo journalctl -u clock-weather -n 50
   ```

3. **Verify documentation**
   - Links work
   - Code examples are correct
   - Instructions are clear

## Pull Request Guidelines

### PR Title

Use clear, descriptive titles:
- ✅ "Add support for custom fonts"
- ✅ "Fix weather API timeout handling"
- ❌ "Update"
- ❌ "Changes"

### PR Description

Include:
- **What** changed
- **Why** it was changed
- **How** it was tested
- **Screenshots** (if UI changes)
- **Breaking changes** (if any)

Template:
```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Testing
How was this tested?
- [ ] Tested on Pi 3B
- [ ] Tested boot sequence
- [ ] Tested weather updates
- [ ] Checked logs for errors

## Screenshots
(if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Tested on actual hardware
```

## Issue Guidelines

### Bug Reports

Include:
- **Description**: What happened?
- **Expected**: What should happen?
- **Steps to reproduce**: How to recreate the bug?
- **Environment**: Pi model, OS version, etc.
- **Logs**: Relevant log excerpts

Template:
```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. Bug occurs

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Raspberry Pi: Model 3B
- OS: Raspberry Pi OS Bookworm
- PiTFT: 3.5" Resistive
- App Version: (commit hash or tag)

## Logs
```
Paste relevant logs here
```

## Additional Notes
Any other relevant information
```

### Feature Requests

Include:
- **Description**: What feature do you want?
- **Use case**: Why is this useful?
- **Examples**: Similar features in other projects?
- **Implementation ideas**: (optional) How might it work?

## Code Review Process

1. **Automated checks**: PRs must pass any CI checks
2. **Manual review**: Maintainer reviews code
3. **Feedback**: Address review comments
4. **Approval**: Maintainer approves
5. **Merge**: Merged into main branch

## Community Guidelines

### Be Respectful

- Be kind and courteous
- Respect different viewpoints
- Accept constructive criticism gracefully
- Focus on the issue, not the person

### Communication

- Use clear, professional language
- Provide helpful feedback
- Be patient with newcomers
- Ask questions if unclear

## Questions?

- **General questions**: Use GitHub Discussions
- **Bug reports**: Use GitHub Issues
- **Security issues**: Email maintainers directly (don't open public issues)

## Recognition

Contributors will be:
- Listed in project contributors
- Credited in release notes
- Appreciated by the community! 🎉

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Getting Help

Need help contributing?
- Read existing issues and PRs for examples
- Ask in GitHub Discussions
- Review documentation in `docs/`

---

**Thank you for contributing to CerberusGo!** 🚀

Every contribution, no matter how small, helps make this project better.
