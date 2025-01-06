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

    private let AUTHORIZED_PRINCIPAL : Text = "ucdbi-ypeup-kyjpa-5hopo-zoin4-jntfn-b4xnt-3tczu-kgpub-5eb76-sqe";

    private stable var transactionsEntries : [(TransactionKey, Transaction)] = [];

    private var transactions = HashMap.HashMap<TransactionKey, Transaction>(
        0,
        func(x: TransactionKey, y: TransactionKey) : Bool {
            x.address == y.address and x.ticker == y.ticker and x.txid == y.txid
        },
        func(x: TransactionKey) : Hash.Hash {
            Text.hash(x.address # x.ticker # x.txid)
        }
    );

    system func preupgrade() {
        transactionsEntries := Iter.toArray(transactions.entries());
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
        transactionsEntries := [];
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
}
