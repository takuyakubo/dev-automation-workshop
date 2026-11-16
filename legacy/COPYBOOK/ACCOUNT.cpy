      *----------------------------------------------------------------
      * 口座マスタ レコード定義（40バイト）
      *----------------------------------------------------------------
       01  ACCT-RECORD.
           05  ACCT-ID              PIC X(8).
           05  ACCT-TYPE            PIC X(1).
           05  ACCT-NAME            PIC X(20).
           05  ACCT-BALANCE         PIC S9(9)
                                    SIGN IS TRAILING SEPARATE.
           05  ACCT-STATUS          PIC X(1).
