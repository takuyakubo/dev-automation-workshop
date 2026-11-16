       IDENTIFICATION DIVISION.
       PROGRAM-ID. INTEREST.
      *----------------------------------------------------------------
      * 月次利息バッチ
      * 起動引数：当月の日数
      * 利息を計算して残高に加算し、新しい口座マスタと明細を出力する。
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OLD-MASTER ASSIGN TO "OLDMAST"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT NEW-MASTER ASSIGN TO "NEWMAST"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT REPORT-FILE ASSIGN TO "INTRPT"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  OLD-MASTER.
       COPY ACCOUNT.
       FD  NEW-MASTER.
       01  NEW-RECORD               PIC X(40).
       FD  REPORT-FILE.
       01  REPORT-RECORD.
           05  RP-ACCT-ID           PIC X(8).
           05  FILLER               PIC X(1).
           05  RP-GROSS             PIC 9(9).
           05  FILLER               PIC X(1).
           05  RP-TAX               PIC 9(9).
           05  FILLER               PIC X(1).
           05  RP-NET               PIC 9(9).

       WORKING-STORAGE SECTION.
       01  WS-ARG                   PIC X(4).
       01  WS-DAYS                  PIC 9(3).
       01  WS-YEAR-DAYS             PIC 9(3) VALUE 365.
       01  WS-RATE                  PIC 9V9(6) VALUE 0.000200.
       01  WS-TAX-RATE              PIC 9V9(5) VALUE 0.20000.
       01  WS-GROSS                 PIC 9(9).
       01  WS-TAX                   PIC 9(9).
       01  WS-NET                   PIC 9(9).
       01  WS-EOF                   PIC X VALUE "N".

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-ARG FROM COMMAND-LINE
           COMPUTE WS-DAYS = FUNCTION NUMVAL(WS-ARG)
           OPEN INPUT OLD-MASTER
                OUTPUT NEW-MASTER REPORT-FILE
           PERFORM UNTIL WS-EOF = "Y"
               READ OLD-MASTER
                   AT END MOVE "Y" TO WS-EOF
                   NOT AT END PERFORM CALC-INTEREST
               END-READ
           END-PERFORM
           CLOSE OLD-MASTER NEW-MASTER REPORT-FILE
           STOP RUN.

       CALC-INTEREST.
      *    利息額の円未満は四捨五入する
           COMPUTE WS-GROSS =
               ACCT-BALANCE * WS-RATE * WS-DAYS / WS-YEAR-DAYS
           COMPUTE WS-TAX = WS-GROSS * WS-TAX-RATE
           COMPUTE WS-NET = WS-GROSS - WS-TAX
           ADD WS-NET TO ACCT-BALANCE
           WRITE NEW-RECORD FROM ACCT-RECORD
           MOVE SPACES TO REPORT-RECORD
           MOVE ACCT-ID TO RP-ACCT-ID
           MOVE WS-GROSS TO RP-GROSS
           MOVE WS-TAX TO RP-TAX
           MOVE WS-NET TO RP-NET
           WRITE REPORT-RECORD.
