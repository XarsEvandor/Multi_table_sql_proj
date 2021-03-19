1. --A simple display all that can be used for any table, very handy in many cases.
select *
from customers
Order by region;

2. --View for calculating some useful values for later calculations. I included the id's so i can easily join the view with 
    --any other view or table.
create or replace view Orders_v1 as
select o.Ord_id, p.Prod_id, w.Warehouse_id
    ,DECODE(INSTR(p.PEGI_rating, '18'), 0, 'NO', 'YES') Rated_R
    ,DECODE(p.Edition, 'Standard', p.Possible_discount-(p.Possible_discount/2), 
    'Deluxe',p.Possible_discount-(p.Possible_discount/4),
    'Gold',p.Possible_discount-(p.Possible_discount/5),
    p.Possible_discount) Final_discount
    ,DECODE(o.Urgency, 'LOW', 0, 'MEDIUM', 15, 30) Urgency_fee
    ,DECODE(w.Shipping, 'LOCAL', 0, 20) Global_shipping_fee
from Online_orders o join Warehouses w
on o.Warehouse_id = w.Warehouse_id
join Games p 
on o.Prod_id = p.Prod_id;

3. -- View that calculates the total shipping cost.
create or replace view Shipping_v2 as
select b.*, c.cust_id
    ,DECODE(c.Prime, 'YES', TO_CHAR(b.Global_shipping_fee*0.6, '$99'),
        TO_CHAR(b.Global_shipping_fee + b.Urgency_fee, '$99')) Total_shipping_cost
from Online_orders o join Orders_v1 b
on b.Ord_id = o.Ord_id
join Customers c
on o.Cust_id = c.Cust_id
order by 1;

4. --View that calculates the total cost of an order.   
create or replace view Total_online_v3 as
select c.*
	,TO_CHAR(p.Retail_price-(p.Retail_price*c.Final_discount)+TO_NUMBER(SUBSTR(c.Total_shipping_cost,
        INSTR(c.Total_shipping_cost,'$')+1)), '$9999.99') Total_online
from Shipping_v2 c join Games p
on c.Prod_id = p.Prod_id;

5. --View for calculating the class discount
create or replace view Class_v4 as
select c.*, DECODE(Cust_class, 'LOW', 0, 'MED', 0.10, 'HIGH', 0.25, 0.4) Class_discount
from Customers c;

6. --View for calculating the total cost of local sales.
create or replace view Total_local_v5 as
select p.*, v.*
    ,TO_CHAR(p.Retail_price - (p.Retail_price * v.Class_discount), '$9999.99') Total_local
from Class_v4 v join Local_sales l
on l.Cust_id = v.Cust_id
join Games p
on l.Prod_id = p.Prod_id;

7.--We create the salary for our employees as well as the total sales by that employee and their revenue. 
    --Note that the numbers are not very realistic but thats the closest to a realistic number i could get when i assume the entire brand has only 400 sales yearly.
    --Normally we would multiply the base salary by 12 and consider the yearly revenue ans total salary. But since the sales are so low, multiplying the salary by 12
    --would cause the total employee salary to exceed their revenue. After asking around i concluded that a sensible number for the local sales yearly woud be around 
    --30.000 for 100 employees. That would make for a really large script file.
create or replace view Salary_v6 as
select TO_CHAR((SUM(TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1)) * e.Commission) + e.Base_sal), '$999999.99') Empl_sal 
    , TO_CHAR(SUM(TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1))), '$9999999.99') Empl_revenue, COUNT(l.Sale_id) Empl_sale_count, e.Empl_id, e.Branch_id
from Total_local_v5 v join Local_sales l
on v.Prod_id = l.Prod_id
join Employees e 
on l.Empl_id = e.Empl_id
group by e.Empl_id, e.Base_sal, e.Branch_id;

8. --Views to calculate total cost and total revenue per branch. We order based on the balance of every shop. Since we have very low sale count we again compromise by
    --using the monthly values od manager salary and util cost as yearly values. We assume that every non-game product sold costs on average $150.
create or replace view Branch_data_v7 as
select TO_CHAR(SUM(TO_NUMBER(SUBSTR(v.Empl_sal,INSTR(v.Empl_sal,'$')+1))) + b.Manager_salary + b.Util_cost, '$999999.99') Branch_cost
    ,TO_CHAR(SUM(TO_NUMBER(SUBSTR(v.Empl_revenue,INSTR(v.Empl_revenue,'$')+1))) + b.sales * 150, '$999999.99') Branch_revenue, b.Branch_id  
from Branches b join Salary_v6 v
on b.Branch_id = v.Branch_id
group by b.Branch_id, b.Manager_salary, b.Util_cost, b.sales;

create or replace view Branch_final_v8 as
select b.*, TO_CHAR((TO_NUMBER(SUBSTR(branch_revenue,INSTR(branch_revenue,'$')+1)) - TO_NUMBER(SUBSTR(branch_cost,INSTR(branch_cost,'$')+1))), '$999999.99') Balance
from Branch_data_v7 b
Order by Balance;

9. --Bookeeping info on the worst performing branch.
select 'The most problematic branch is ' || v.Branch_id || '. It nets a total revenue of ' || 
    TO_CHAR(SUM(TO_NUMBER(SUBSTR(v.branch_revenue,INSTR(v.branch_revenue,'$')+1))), '$999,999.99') ||
    ' and looses ' || TO_CHAR(SUM(TO_NUMBER(SUBSTR(v.branch_cost,INSTR(v.branch_cost,'$')+1))), '$999,999.99') || ', putting it at a total yearly balance of ' ||
    v.Balance || '. Manager ' || b.Manager_id || ', should be repremanded.' Bookkeeping
from Branch_final_v8 v join Branches b 
on v.Branch_id = b.Branch_id
where rownum = 1
group by v.Branch_id, v.Balance, b.Manager_id;

10. --A tabulation showing the clean revenue from local sales based on customer class. We only care about local sales here since they are the ones affected by cust_class
select TO_CHAR(SUM(DECODE(c.Cust_class, 'LOW', TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1)), 0)), '$999,999.99') LOW
    ,TO_CHAR(SUM(DECODE(c.Cust_class, 'MED', TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1)), 0)), '$999,999.99') MED
    ,TO_CHAR(SUM(DECODE(c.Cust_class, 'HIGH', TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1)), 0)), '$999,999.99') HIGH
    ,TO_CHAR(SUM(DECODE(c.Cust_class, 'VIP', TO_NUMBER(SUBSTR(V.Total_local,INSTR(V.Total_local,'$')+1)), 0)), '$999,999.99') VIP
from Customers c join Local_sales l
on c.Cust_id = l.Cust_id
join Total_local_v5 v 
on v.Prod_id = l.Prod_id;

11. --A constest based on the card credit of the customers.
create or replace view Credit_v9 as
select credit, Card_id
from (
    select credit, Card_id, Card_status
    from Cards
    where Card_status != 'INACTIVE'
    order by 1 desc
)
where rownum = 1;

select DECODE(c.Cust_gender, 'Male', 'Mr.', 'Female', 'Ms.', 'Mx.') || ' ' || c.Cust_name || 'has collected ' || b.Credit || 
    ' credits this year and is thus the winner of our reward, a volcano lair, that comes fully equiped with a rotating chair and a white cat to pet menancingly, 
    courtesy of our sponcor, evil.inc. The winner will be notified of their reward by a mail sent to their adress at ' || c.Cust_address || '.' Result
from Customers c join Credit_v9 b
on c.Cust_card_code = b.Card_id;