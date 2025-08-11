#Voting Machine Hardware Design (Verilog, Altera DE2-115)

Description
A hardware implementation of a voting machine designed for the Altera DE2-115 FPGA board.
Supports up to 16 candidates, one vote per person, with a manual reset for candidate selection.
Includes a finite state machine (FSM) to manage voting sessions, vote confirmation, session timeouts, and tally display.

Tech Stack
Language: SystemVerilog (IEEE 1800 standard)
Hardware: Altera DE2-115 FPGA Development Board
Toolchain: Intel Quartus Prime / ModelSim

Features
Supports 16 candidates with single active selection.
Vote confirmation via push button with LED blink feedback.
Session timeout if no vote is confirmed within a set period.
Tally mode to display total votes for a selected candidate.
Error display for invalid selections (multiple or no candidates).
All-in-one file — FSM, timing logic, candidate detection, and display control.

Modular design: VoteMach (top), CandidateSelector, ClockDivider, HexDisplay.

| Action           | HEX Display | LED Status           |
| ---------------- | ----------- | -------------------- |
| Vote confirmed   | DONE        | Candidate LED blinks |
| Timeout          | tOE         | No LEDs lit          |
| Tally (42 votes) | 0042        | Candidate LED solid  |
