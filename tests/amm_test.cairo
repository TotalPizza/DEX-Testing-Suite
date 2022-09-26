%lang starknet

from protostar.asserts import assert_eq

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_eq,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_signed_div_rem,
    uint256_unsigned_div_rem,
)
from src.lib.utils import Utils
from src.interfaces.IERC20 import IERC20
from src.interfaces.IRouter import IJedi_router, ISith_router, ITenK_router
from src.interfaces.IEmpiric_oracle import IEmpiric_oracle

const base = 1000000000000000000;  // 1e18
const small_base = 1000000;  // 1e6
const extra_base = 100000000000000000000;  // We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044;
    %{ context.public_key_0 = ids.public_key_0 %}

    //////////////////////
    // Deploy Mock_Tokens
    //////////////////////
    local shitcoin1: felt;
    %{ ids.shitcoin1 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12343,343,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin1 = ids.shitcoin1 %}
    // %{ print("shitcoin1 Address: ",ids.shitcoin1) %}
    local shitcoin2: felt;
    %{ ids.shitcoin2 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12344,344,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin2 = ids.shitcoin2 %}
    // %{ print("shitcoin2 Address: ",ids.shitcoin2) %}
    local USDC: felt;
    %{ ids.USDC = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12345,345,6,100000000*ids.small_base,0,ids.public_key_0]).contract_address %}
    %{ context.USDC = ids.USDC %}
    // %{ print("USDC Address: ",ids.USDC) %}
    local ETH: felt;
    %{ ids.ETH = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12346,346,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.ETH = ids.ETH %}
    // %{ print("ETH Address: ",ids.ETH) %}
    local USDT: felt;
    %{ ids.USDT = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12347,347,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.USDT = ids.USDT %}
    // %{ print("USDT Address: ",ids.USDT) %}
    local DAI: felt;
    %{ ids.DAI = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12348,348,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.DAI = ids.DAI %}
    // %{ print("DAI Address: ",ids.DAI) %}
    
    
    //////////////////
    // Set routers
    //////////////////
    
    let (local router_1_address) = create_jedi_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 1: ",ids.router_1_address) %}
    let (local router_2_address) = create_sith_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 2: ",ids.router_2_address) %}
    let (local router_3_address) = create_TenK_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 3: ",ids.router_3_address) %}

    %{ context.router_1_address = ids.router_1_address %}
    %{ context.router_2_address = ids.router_2_address %}
    %{ context.router_3_address = ids.router_3_address %}

    // Deploy Price Oracle
    local mock_oracle_address: felt;
    %{
        context.mock_oracle_address = deploy_contract("./src/mocks/mock_price_oracle.cairo", []).contract_address 
        ids.mock_oracle_address = context.mock_oracle_address
    %}

    // Set Global Prices for Mock ERC20s in Mock_Price_Feed
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.mock_oracle_address) %}
    // ETH/USD, key: 28556963469423460
    IEmpiric_oracle.set_token_price(mock_oracle_address, 28556963469423460, 0, 1000 * base, 18);
    // USDC/USD, key: 8463218501920060260
    IEmpiric_oracle.set_token_price(mock_oracle_address, 8463218501920060260, 0, 1 * base, 18);
    // USDT/USD, key: 8463218574934504292
    IEmpiric_oracle.set_token_price(mock_oracle_address, 8463218574934504292, 0, 1 * base, 18);
    // DAI/USD, key: 28254602066752356
    IEmpiric_oracle.set_token_price(mock_oracle_address, 28254602066752356, 0, 1 * base, 18);
    // Shitcoin1/USD, key: 99234898239
    IEmpiric_oracle.set_token_price(mock_oracle_address, 99234898239, 0, 10 * base, 18);
    // Shitcoin2/USD, key: 23674728373
    IEmpiric_oracle.set_token_price(mock_oracle_address, 23674728373, 0, 10 * base, 18);
    %{ stop_prank_callable() %}

    return ();
}

@external
func test_solver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    //ADMIN
    local public_key_0;
    %{ ids.public_key_0 = context.public_key_0 %}
    
    //TOKENS
    local ETH;
    %{ ids.ETH = context.ETH %}
    local DAI;
    %{ ids.DAI = context.DAI %}
    local USDC;
    %{ ids.USDC = context.USDC %}
    local USDT;
    %{ ids.USDT = context.USDT %}
    local shitcoin1;
    %{ ids.shitcoin1 = context.shitcoin1 %}
    local shitcoin2;
    %{ ids.shitcoin2 = context.shitcoin2 %}

    //Price Oracle
    local shitcoin2;
    %{ ids.shitcoin2 = context.shitcoin2 %}

    //DEX routers
    local router_1_address;
    %{ ids.router_1_address = context.router_1_address %}
    local router_2_address;
    %{ ids.router_2_address = context.router_2_address %}
    local router_3_address;
    %{ ids.router_3_address = context.router_3_address %}

    return ();
}

func create_jedi_router{syscall_ptr: felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt,
    ) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_jedi_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    // Set Reserves
    IJedi_router.set_reserves(router_address, shitcoin1, ETH, Uint256(10000 * base, 0), Uint256(100 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, shitcoin1, DAI, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, ETH, USDT, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(10 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
    IERC20.transfer(shitcoin1, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(shitcoin1, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(10000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}

func create_sith_router{syscall_ptr: felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt,
    ) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_sith_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(1000 * base, 0), Uint256(1000000 * base, 0));  // 1,000,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(1000000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}

func create_TenK_router{syscall_ptr: felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt,
    ) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_TenK_router.cairo", []).contract_address %}


    IJedi_router.set_reserves(router_address, shitcoin1, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    IJedi_router.set_reserves(router_address, shitcoin2, DAI, Uint256(10000 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, shitcoin2, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin2) %}
    IERC20.transfer(shitcoin2, router_address, Uint256(1000 * base, 0));
    IERC20.transfer(shitcoin2, router_address, Uint256(10000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
    IERC20.transfer(shitcoin1, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(10000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}
