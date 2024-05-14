module defi::credit {
    use std::string;
    use std::vector;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::event;

    struct CreditRequest has key, store {
        id: UID,
        amount: u64,
        reason: string::String,
        loans: vector<Loan>
    }

    struct Loan has key, store {
        id: UID,
        balance: Balance<SUI>
    }

     struct CreditRequetCreatedEvent has copy, drop {
        request_id: ID,
        requester: address,
        amount: u64
    }

    public entry fun createCreditRequest(amount: u64, reason: string::String, ctx: &mut TxContext) {
        let request = CreditRequest {
            id: object::new(ctx),
            amount,
            reason,
            loans: vector<Loan>[]
        };

        // TODO: Emit event after transfer
        event::emit(CreditRequetCreatedEvent {
            request_id: object::uid_to_inner(&request.id),
            requester: tx_context::sender(ctx),
            amount
        });

        transfer::public_transfer(request, tx_context::sender(ctx));        
    }

    public entry fun addLoan(application: &mut CreditRequest, _coin: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext) {
        let remain: u64 = getMissingFounds(application);

        assert!(coin::value(_coin) >= amount, 0);
        assert!(amount <= remain, 0);

        let loanCoin = coin::split(_coin, amount, ctx);

        let balance = coin::into_balance(loanCoin);

        let loan = Loan {
            id: object::new(ctx),
            balance
        };

        vector::push_back(&mut application.loans, loan);
    }

    public entry fun executeCreditRequest(application: &mut CreditRequest, ctx: &mut TxContext) {
        assert!(getMissingFounds(application) == 0, 0);

        let CreditRequest {
            id: _id,
            amount: _amount,
            loans: loans,
            reason: _reason
        } = application;

        let app_length = vector::length(loans);
        let index: u64 = 0;
        let creditBalance: Balance<SUI> = balance::zero();

        while(index < app_length) {
            let loan = vector::borrow_mut(&mut application.loans, index);
            let loanBalance = balance::withdraw_all(&mut loan.balance);
            balance::join(&mut creditBalance, loanBalance);
        };

        transfer::public_transfer(coin::from_balance(creditBalance, ctx), tx_context::sender(ctx));

        // TODO: Freezing the credit object after it has been anchored
    }

    fun getMissingFounds(application: &CreditRequest): u64 {
        let collected: u64 = 0;
        let app_length = vector::length(&application.loans);
        let index: u64 = 0;

        while(index < app_length) {
            let loan = vector::borrow(&application.loans, index);
            collected = collected + balance::value(&loan.balance);
            index = index + 1;
        };

        let missingFounds = application.amount - collected;

        return missingFounds
    }
}
