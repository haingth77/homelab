# AI Agent Root Rules

This document outlines the foundational principles and operational guidelines for all AI agents within this system. Adherence to these rules is mandatory to ensure safety, efficiency, and consistency in a multi-agent product development environment.

## Core Mandates

- **Convention Adherence:** Agents must rigorously adhere to existing project conventions when reading or modifying code. Analyze surrounding code, tests, and configuration before making any changes.
- **Library/Framework Usage:** Never assume a library or framework is available. Verify its established usage within the project before employing it.
- **Style & Structure:** Mimic the style, structure, and architectural patterns of the existing codebase to ensure all contributions are idiomatic.
- **Planning & Review:** All actions and significant changes must be thoroughly planned and undergo review by a designated managing agent or human user before execution.
- **Proactive Quality:** Fulfill requests thoroughly. This includes adding tests to ensure the quality and correctness of new features or bug fixes.
- **Clarification:** Do not take significant actions beyond the clear scope of a request without first confirming with the user or a managing agent.

## Operational Guidelines

- **Conciseness:** Communication should be professional, direct, and concise, suitable for a CLI environment. Avoid conversational filler.
- **Tool Usage:** Use tools for actions and text output for communication. Do not add explanatory comments within tool calls.
- **Security First:** Apply security best practices at all times. Never introduce code that exposes, logs, or commits secrets, API keys, or other sensitive information. Explain all critical commands before execution.
- **Technology Selection:** When selecting or recommending technologies, agents must prioritize enterprise-grade solutions (even if using free/community versions) that offer clear capabilities for integration with agentic AI systems.
- **Git Workflow:**
    - Never commit changes unless explicitly instructed.
    - Always review `git status` and `git diff` before creating a commit.
    - Match the style of recent commit messages.
    - Never push changes to a remote repository without explicit user instruction.

### Documentation Standards

- **Action Documentation:** All significant actions and changes performed by an agent must be documented. Where applicable, use Mermaid diagrams to illustrate processes, interactions, and system states for enhanced understanding.
- **Reference Adherence:** Agents must consult and adhere to existing project documentation, including "approach documents" for overall navigation and detailed guides for technology-specific setups and configurations.

## Collaboration Principles

- **Structured Communication:** Agents will communicate using a structured format (e.g., JSON or YAML) to pass information and requests to one another. The specific schemas will be defined on a per-skill or per-task basis.
- **Inter-agent Synchronization:** Agents must actively synchronize with other relevant roles to ensure alignment, prevent redundant work, and ensure all efforts contribute cohesively towards shared objectives.
- **Role-Based Tasking:** Agents must respect the designated roles of other agents. Tasks should be delegated to the agent with the appropriate expertise.
- **State Management:** When a task is handed off, the originating agent is responsible for providing all necessary context and state required for the receiving agent to continue the work.
