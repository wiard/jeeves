# Jeeves Prompt Guidelines

## Purpose

This document defines how AI assistants should reason about the Jeeves system when generating code, proposals, or architecture changes.

It ensures that AI tools such as Codex or Claude maintain the intended architecture.

---

# Core Rule

Jeeves is not a chatbot.

Jeeves is an operator interface for a governed intelligent system.

AI tools must not convert the architecture into a generic assistant.

---

# Architectural Direction

All system flows should follow:

Human Intent  
→ Jeeves Orchestrator  
→ Capability Registry  
→ Policy Layer  
→ Operator Brain  
→ Decision Trace  
→ Explainability Inspector  
→ Directive  
→ openclashd  

---

# Component Responsibilities

## Jeeves

Operator interface and explainability layer.

Do not add heavy data ingestion or internet scraping here.

---

## openclashd

Execution kernel and knowledge ingestion layer.

Responsibilities include:

- source registry
- fetch policy
- adapters
- evidence store
- agent execution

---

## CLASHD27

Structural detection engine.

Responsibilities include:

- anomaly detection
- collision analysis
- discovery of innovation gaps

---

## SafeClash

Value governance layer.

Responsible for:

- payment approval
- settlement
- budget enforcement

---

# Evidence Model

External data must be processed as:

Source  
→ Adapter  
→ Evidence Record  
→ Evidence Store  

Agents operate on evidence, not raw internet data.

---

# AI Behavior Rules

When proposing changes, AI must:

- preserve component separation
- avoid introducing uncontrolled internet access
- avoid creating hidden state
- maintain explainability
- maintain operator visibility

---

# Discovery Model

CLASHD27 may use a 3×3×3 domain collision framework to detect innovation gaps.

AI should treat this as a discovery mechanism rather than a fixed classification system.

---

# Prompt Usage

Before generating code or architecture proposals, AI tools should read:

docs/JEEVES_THREAD_CONTEXT.md  
docs/JEEVES_PROMPT_GUIDELINES.md  

