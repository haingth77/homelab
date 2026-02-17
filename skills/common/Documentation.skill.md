# Documentation Common Skill

This skill defines the standardized approach for all agents to generate, maintain, and utilize documentation within the system. It adheres to the `root_rules.md` regarding documentation standards and aims to ensure clarity, consistency, and traceability across all agent-generated artifacts.

## Adherence to Root Rules

This Documentation Skill shall strictly adhere to the "Documentation Standards" outlined in `../../agents/root_rules.md`.

## Responsibilities

Any agent invoking this skill is responsible for:
- **Generating Clear Documentation:** Producing clear, concise, and accurate documentation for their actions, designs, and outputs.
- **Utilizing Mermaid Diagrams:** Employing Mermaid syntax to generate diagrams (e.g., flowcharts, sequence diagrams, class diagrams) whenever a visual representation can enhance understanding of processes, interactions, or system states.
- **Adhering to Project Standards:** Ensuring all generated documentation conforms to project-specific formatting, terminology, and storage conventions.
- **Linking to References:** Cross-referencing relevant "approach documents" and technology-specific configuration guides as needed.
- **Maintaining Documentation:** Updating existing documentation to reflect changes in functionality, design, or implementation.

## Input

Agents invoking this skill should provide:
- **Content for Documentation:** Raw information, descriptions, or data to be documented.
- **Type of Documentation:** (e.g., `process_flow`, `system_design`, `api_spec`, `user_guide`).
- **Mermaid Diagram Type (Optional):** Specify if a Mermaid diagram is required (e.g., `flowchart`, `sequence`, `class`) and the corresponding Mermaid syntax/structure.
- **Target Audience:** Who the documentation is for (e.g., `developers`, `stakeholders`, `end_users`).

## Output

This skill will produce:
- Formatted documentation content (e.g., Markdown, AsciiDoc).
- Rendered Mermaid diagrams (if applicable, or the Mermaid syntax to be rendered by an external tool).
- Links to relevant existing documentation or generated documents.

## Best Practices

- **Contextual Documentation:** Provide documentation that is relevant to the context of the work being performed.
- **Automated Generation:** Where possible, leverage automation to generate or update documentation to reduce manual effort and ensure accuracy.
- **Version Control:** Store all documentation in version control systems alongside the code it describes.
- **Regular Review:** Periodically review and update documentation to ensure it remains current and accurate.
- **Diagram-First Approach:** For complex processes or systems, consider sketching out a Mermaid diagram *before* writing detailed text to clarify the logic.
