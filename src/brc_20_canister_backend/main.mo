import Hash "mo:base/Hash";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Error "mo:base/Error";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

actor TransactionManager {
    private type Transaction = {
        address: Text;
        ticker: Text;
        txid: Text;
        from: Text;
        amount: Nat;
    };

    private type TransactionKey = {
        address: Text;
        ticker: Text;
        txid: Text;
    };

    private type Transfer = {
        p_txid: Text;
        txid: Text;
        vout: Nat;
        value: Nat;
        ticker: Text;
        amount: Nat;
    };

    private type TransferKey = {
        p_txid: Text;
    };

    private let AUTHORIZED_PRINCIPAL : Text = "pxtgs-skt27-2rxsh-6r2pf-4jyqd-6yzo3-fwck3-5wyho-piwgl-vktbi-bqe";

    private stable var transactionsEntries : [(TransactionKey, Transaction)] = [];
    private stable var transfersEntries : [(TransferKey, Transfer)] = []; 

    private var transactions = HashMap.HashMap<TransactionKey, Transaction>(
        0,
        func(x: TransactionKey, y: TransactionKey) : Bool {
            x.address == y.address and x.ticker == y.ticker and x.txid == y.txid
        },
        func(x: TransactionKey) : Hash.Hash {
            Text.hash(x.address # x.ticker # x.txid)
        }
    );

    // New HashMap for transfers
    private var transfers = HashMap.HashMap<TransferKey, Transfer>(
        0,
        func(x: TransferKey, y: TransferKey) : Bool {
            x.p_txid == y.p_txid
        },
        func(x: TransferKey) : Hash.Hash {
            Text.hash(x.p_txid)
        }
    );

    system func preupgrade() {
        transactionsEntries := Iter.toArray(transactions.entries());
        transfersEntries := Iter.toArray(transfers.entries()); 
    };

    system func postupgrade() {
        transactions := HashMap.fromIter<TransactionKey, Transaction>(
            transactionsEntries.vals(),
            0,
            func(x: TransactionKey, y: TransactionKey) : Bool {
                x.address == y.address and x.ticker == y.ticker and x.txid == y.txid
            },
            func(x: TransactionKey) : Hash.Hash {
                Text.hash(x.address # x.ticker # x.txid)
            }
        );
        
        transfers := HashMap.fromIter<TransferKey, Transfer>(
            transfersEntries.vals(),
            0,
            func(x: TransferKey, y: TransferKey) : Bool {
                x.p_txid == y.p_txid
            },
            func(x: TransferKey) : Hash.Hash {
                Text.hash(x.p_txid)
            }
        );
        
        transactionsEntries := [];
        transfersEntries := [];
    };

    private func isAuthorized() : Bool {
        let caller = Principal.toText(Principal.fromActor(TransactionManager));
        caller == AUTHORIZED_PRINCIPAL
    };

    public shared(msg) func uploadbrc20data(
        address: Text,
        ticker: Text,
        txid: Text,
        from: Text,
        amount: Nat
    ) : async Result.Result<Text, Text> {
        if (Principal.toText(msg.caller) != AUTHORIZED_PRINCIPAL) {
            return #err("Unauthorized: Only admin call upload");
        };
        let key : TransactionKey = {
            address = address;
            ticker = ticker;
            txid = txid;
        };

        let transaction : Transaction = {
            address = address;
            ticker = ticker;
            txid = txid;
            from = from;
            amount = amount;
        };

        transactions.put(key, transaction);
        #ok("brc20 uploaded successfully")
    };

    public shared(msg) func uploadtransferdata(
        p_txid: Text,
        txid: Text,
        vout: Nat,
        value: Nat,
        ticker: Text,
        amount: Nat
    ) : async Result.Result<Text, Text> {
        if (Principal.toText(msg.caller) != AUTHORIZED_PRINCIPAL) {
            return #err("Unauthorized: Only admin can upload transfer data");
        };

        let key : TransferKey = {
            p_txid = p_txid;
        };

        let transfer : Transfer = {
            p_txid = p_txid;
            txid = txid;
            vout = vout;
            value = value;
            ticker = ticker;
            amount = amount;
        };

        transfers.put(key, transfer);
        #ok("Transfer data uploaded successfully")
    };

    public query func querytransfer(
        p_txid: Text
    ) : async Result.Result<(Text, Nat, Nat, Text, Nat), Text> {
        let key : TransferKey = {
            p_txid = p_txid;
        };

        switch (transfers.get(key)) {
            case (null) {
                #err("Transfer data not found")
            };
            case (?transfer) {
                #ok((transfer.txid, transfer.vout, transfer.value, transfer.ticker, transfer.amount))
            };
        }
    };

    public shared(msg) func clearAllTransactions() : async Result.Result<Text, Text> {
        if (Principal.toText(msg.caller) != AUTHORIZED_PRINCIPAL) {
            return #err("Unauthorized: Only admin can clear transactions");
        };
        
        transactions := HashMap.HashMap<TransactionKey, Transaction>(
            0,
            func(x: TransactionKey, y: TransactionKey) : Bool {
                x.address == y.address and x.ticker == y.ticker and x.txid == y.txid
            },
            func(x: TransactionKey) : Hash.Hash {
                Text.hash(x.address # x.ticker # x.txid)
            }
        );
        
        return #ok("All transactions cleared successfully");
    };

    public shared(msg) func clearAllTransfers() : async Result.Result<Text, Text> {
        if (Principal.toText(msg.caller) != AUTHORIZED_PRINCIPAL) {
            return #err("Unauthorized: Only admin can clear transfers");
        };
        
        transfers := HashMap.HashMap<TransferKey, Transfer>(
            0,
            func(x: TransferKey, y: TransferKey) : Bool {
                x.p_txid == y.p_txid
            },
            func(x: TransferKey) : Hash.Hash {
                Text.hash(x.p_txid)
            }
        );
        
        return #ok("All transfers cleared successfully");
    };

    public query func querybrc20(
        address: Text,
        ticker: Text,
        txid: Text
    ) : async Result.Result<(Text, Nat), Text> {
        let key : TransactionKey = {
            address = address;
            ticker = ticker;
            txid = txid;
        };

        switch (transactions.get(key)) {
            case (null) {
                #err("brc20 tx not found")
            };
            case (?transaction) {
                #ok((transaction.from, transaction.amount))
            };
        }
    };

    public query func gettxaccount() : async Nat {
        transactions.size()
    };

    public query func gettransferaccount() : async Nat {
        transfers.size()
    };
}
