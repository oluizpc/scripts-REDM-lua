# REDM Lua Scripts – Base VORP & Estudos

Repositório focado em **estudos, testes e desenvolvimento de scripts para RedM**, utilizando **VORP Core** como base.

Este projeto **não é um servidor pronto para produção**.  
Ele funciona como um **ambiente de aprendizado**, onde novos scripts são criados, testados, refatorados e evoluídos conforme o estudo avança.

---

## Objetivo do Repositório

- Servir como **base mínima de resources para iniciar um servidor VORP**
- Centralizar **scripts de estudo e testes práticos**
- Evoluir scripts do zero, focando em:
  - lógica server-side
  - segurança
  - boas práticas
  - arquitetura correta para RedM
- Documentar aprendizado real (tentativa, erro e melhoria)

---

## Tecnologias Utilizadas

- **RedM**
- **Lua**
- **VORP Core**
- Arquitetura **server-first**
- Separação clara entre `server.lua`, `client.lua` e `config.lua`

---

## Estrutura do Repositório

```text
scripts-REDM-lua/
│
├── frp_cova/
│   ├── client.lua
│   ├── server.lua
│   └── fxmanifest.lua
│
├── drp_drugdealer/
│   ├── client.lua
│   ├── server.lua
│   └── fxmanifest.lua
│
└── README.md
```

## Scripts Atuais

### frp_cova
**Roubo de covas (grave robbery)**

- Sistema de interação com covas  
- Controle de tempo e cooldown  
- Loot configurável  
- Validações server-side  

**Base pronta para:**
- alerta policial  
- witnesses  
- melhorias de RP  

**Status:** funcional / em evolução  

---

### drp_drugdealer
**Entrega de drogas para NPCs**

- Interação com NPCs  
- Sistema de chance  
- Controle de cooldown  

**Base para:**
- risco policial  
- progressão  
- reputação  

**Status:** funcional / em evolução  

---

## Importante Saber

**Este repositório contém scripts experimentais**

Alguns scripts:
- não estão otimizados  
- não seguem padrão final de produção  

O foco é **aprendizado e evolução**.  
Mudanças podem ocorrer sem aviso.

---

## Filosofia de Desenvolvimento

- Server decide, client executa  
- Nada crítico confiado ao client  
- Evitar SQL direto sempre que possível  
- Usar VORP como fonte única da verdade  
- Código legível > código curto  

---

## Como Utilizar

Clone o repositório:

```bash
git clone https://github.com/oluizpc/scripts-REDM-lua.git

