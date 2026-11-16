       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEPOSIT.
      *----------------------------------------------------------------
      * 入出金バッチ
      * 口座マスタと取引ファイルを口座番号順に突き合わせ、
      * 新しい口座マスタと拒否リストを出力する。
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       OBJECT-COMPUTER. IBM-370
           PROGRAM COLLATING SEQUENCE IS EBC-SEQ.
       SPECIAL-NAMES.
           ALPHABET EBC-SEQ IS EBCDIC.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OLD-MASTER ASSIGN TO "OLDMAST"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT TX-FILE ASSIGN TO "TXFILE"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT NEW-MASTER ASSIGN TO "NEWMAST"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT REJECT-FILE ASSIGN TO "REJECT"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  OLD-MASTER.
       COPY ACCOUNT.
       FD  TX-FILE.
       01  TX-RECORD.
           05  TX-ACCT-ID           PIC X(8).
           05  TX-TYPE              PIC X(1).
           05  TX-AMOUNT            PIC 9(9).
           05  TX-OFF-HOURS         PIC X(1).
       FD  NEW-MASTER.
       01  NEW-RECORD               PIC X(40).
       FD  REJECT-FILE.
       01  REJECT-RECORD.
           05  RJ-TX                PIC X(19).
           05  FILLER               PIC X(1).
           05  RJ-REASON            PIC X(8).

       WORKING-STORAGE SECTION.
       01  WS-MAST-ID               PIC X(8).
       01  WS-TX-ID                 PIC X(8).
       01  WS-PREV-TX-ID            PIC X(8) VALUE LOW-VALUES.
       01  WS-LIMIT                 PIC 9(9) VALUE 500000.
       01  WS-FEE-AMOUNT            PIC 9(3) VALUE 110.
       01  WS-FEE                   PIC 9(3).
       01  WS-TOTAL                 PIC 9(10).

       PROCEDURE DIVISION.
       MAIN-PARA.
           OPEN INPUT OLD-MASTER TX-FILE
                OUTPUT NEW-MASTER REJECT-FILE
           PERFORM READ-MASTER
           PERFORM READ-TX
           PERFORM UNTIL WS-MAST-ID = HIGH-VALUES
                     AND WS-TX-ID = HIGH-VALUES
               EVALUATE TRUE
                   WHEN WS-TX-ID < WS-MAST-ID
                       MOVE "NOACCT" TO RJ-REASON
                       PERFORM WRITE-REJECT
                       PERFORM READ-TX
                   WHEN WS-TX-ID = WS-MAST-ID
                       PERFORM APPLY-TX
                       PERFORM READ-TX
                   WHEN OTHER
                       WRITE NEW-RECORD FROM ACCT-RECORD
                       PERFORM READ-MASTER
               END-EVALUATE
           END-PERFORM
           CLOSE OLD-MASTER TX-FILE NEW-MASTER REJECT-FILE
           STOP RUN.

       APPLY-TX.
           IF ACCT-STATUS = "F"
               MOVE "FROZEN" TO RJ-REASON
               PERFORM WRITE-REJECT
           ELSE
               IF TX-TYPE = "D"
                   ADD TX-AMOUNT TO ACCT-BALANCE
               ELSE
                   PERFORM WITHDRAW
               END-IF
           END-IF.

       WITHDRAW.
           IF TX-AMOUNT > WS-LIMIT
               MOVE "LIMIT" TO RJ-REASON
               PERFORM WRITE-REJECT
           ELSE
               MOVE ZERO TO WS-FEE
               IF TX-OFF-HOURS = "Y" AND ACCT-TYPE NOT = "9"
                   MOVE WS-FEE-AMOUNT TO WS-FEE
               END-IF
               COMPUTE WS-TOTAL = TX-AMOUNT + WS-FEE
               IF WS-TOTAL > ACCT-BALANCE
                   MOVE "SHORT" TO RJ-REASON
                   PERFORM WRITE-REJECT
               ELSE
                   SUBTRACT WS-TOTAL FROM ACCT-BALANCE
               END-IF
           END-IF.

       WRITE-REJECT.
           MOVE TX-RECORD TO RJ-TX
           WRITE REJECT-RECORD.

       READ-MASTER.
           READ OLD-MASTER
               AT END MOVE HIGH-VALUES TO WS-MAST-ID
               NOT AT END MOVE ACCT-ID TO WS-MAST-ID
           END-READ.

       READ-TX.
           READ TX-FILE
               AT END MOVE HIGH-VALUES TO WS-TX-ID
               NOT AT END
                   MOVE TX-ACCT-ID TO WS-TX-ID
                   IF WS-TX-ID < WS-PREV-TX-ID
      *                順序異常。NEWMAST は破棄し、前世代から再実行する
                       DISPLAY "SEQUENCE ERROR " WS-TX-ID
                       MOVE 16 TO RETURN-CODE
                       STOP RUN
                   END-IF
                   MOVE WS-TX-ID TO WS-PREV-TX-ID
           END-READ.
