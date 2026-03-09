# Jeeves Orchestrator

Jeeves is **not a chatbot**.

Jeeves is the **operator interface** for the OpenClashd system.

The chat interface is a **command surface** that translates human intent
into actions inside the Jeeves application and the OpenClashd kernel.

---

# Core Principle

Human intent is transformed into governed system behavior.

Flow:

Human Intent  
→ Jeeves Orchestrator  
→ Screen Directive  
→ Gateway Action  
→ Kernel Execution  
→ Knowledge Artifact  

---

# Architecture Layers

The orchestration pipeline works in the following layers:

User input  
↓  
JeevesOrchestrator  
↓  
JeevesDirective  
↓  
ScreenStatePreset  
↓  
UI Navigation / Screen Rendering  
↓  
Gateway Action  
↓  
OpenClashd Kernel  
↓  
Knowledge Objects

---

# Responsibilities

## Jeeves Orchestrator

The orchestrator interprets user intent and decides:

• which screen should be opened  
• which data should be shown  
• whether an action should be executed  
• whether a gateway call should be triggered

The orchestrator does **not execute system logic itself**.

Execution always happens through the **OpenClashd gateway and kernel**.

---

# Directive System

A directive contains:
