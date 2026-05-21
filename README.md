# Micro-UART Design & Verification

## Project Information
- **Author:** Parth Jani
- **Roll Number:** 6916
- **Project Type:** RTL Design and Functional Verification
- **Language:** Verilog HDL
- **Simulation Tools:** Vivado, Questa SIM
- **Date:** May 2026

---

## Project Overview

This project implements a fully parameterized **Micro-UART (Universal Asynchronous Receiver/Transmitter)** using **Verilog HDL** and performs complete **functional verification using a self-checking testbench**.

The design supports asynchronous serial communication through dedicated **Transmitter (Tx)** and **Receiver (Rx)** modules along with a shared **Baud Rate Generator**.

The UART architecture supports:

- Parameterized baud rate
- Configurable data width
- RTL-level implementation
- Functional verification
- Coverage-driven validation
- 16× oversampling for receiver robustness

---

## Project Objectives

- Design synthesizable UART RTL.
- Implement configurable communication parameters.
- Develop self-checking verification environment.
- Validate FSM state transitions.
- Perform functional coverage analysis.
- Generate simulation and verification reports.

---

## Project Architecture

The UART design follows hierarchical architecture:
