create table texas(
             TransactionID varchar2(40) primary key,
             TransactionStartDateTime date,
             TransactionEndDateTime date,
             CardholderID  varchar2(20),             
             LocationID  varchar2(10),
             TransactionTypeID number,
             TransactionAmount number,
             CONSTRAINT fk_cardholder FOREIGN KEY (CardholderID) REFERENCES dim_customers(CardholderID),
             CONSTRAINT fk_transtype FOREIGN KEY (TransactionTypeID) REFERENCES dim_transaction_type(TransactionTypeID)

);

create table dim_transaction_type (
               TransactionTypeID number primary key,
               TransactionTypeName varchar2(20)

);

create table dim_customers (
               CardholderID varchar2(20) primary key,
               FirstName varchar2(30),
               LastName  varchar2(30),
               Gender  varchar2(2),
               ATMID  varchar2(20),
               BirthDate  date,
               Occupation  varchar2(40),
               AccountType  varchar2(20),
               IsMegabank  number
);

create table dim_locations(
              LocationID varchar2(20) primary key,
              LocationName varchar2(30),
              No_of_ATMs number,
              City varchar(30),
              State varchar2(30),
              Country varchar2(30)
              
);



--1. Hər müştərinin sonuncu tranzaksiyasının tarixi və həmin tarixdən bugünədək neçə gün keçdiyinin ekrana çıxardılması

select t.cardholderid as customer,
       max(t.transactionenddatetime) as last_transaction,
       round(sysdate - max(t.transactionenddatetime)) as day_passed
from texas t
group by t.cardholderid
order by  t.cardholderid;



--2. Ən böyük məbləğli tranzaksiyanı edən şəxsin adı və hansı məbləğdə tranzaksiya etdiyi və hansı peşənin sahibi olması

select *
from
(select d.firstname,
       d.lastname,
       d.occupation,
       (select max(t.transactionamount)
        from texas t
        where d.cardholderid=t.cardholderid) as amount
from dim_customers d
where d.cardholderid in (select t.cardholderid
                         from texas t)
)  a
where  a.amount = (select max(t.transactionamount)
                   from texas t)



--3. Heç tranzaksiya etməmiş neçə müştərinin sayının təyini

select count(*)
from dim_customers d
where d.cardholderid not in (select t.cardholderid
                             from texas t)                     

--4. Hər müştəriyə görə tranzaksiya məbləği ortalamasının tapılması və yalnız tam hissə məbləğlərin yuvarlaşdırılaraq kəsr hissəsiz ekrana çıxardılması. 
--Burada müştəri adlarını ekrana çıxararkən bütün adların bütün simvollarının böyük hərflə qeyd edilməsi lazımdır.

select upper(d.firstname) as ad,
       d.lastname,
       (select round(avg(t.transactionamount))
        from texas t
        where d.cardholderid=t.cardholderid) as average              
from dim_customers d
where d.cardholderid in (select t.cardholderid          
                             from texas t)


--5. Ən uzun müddətli 10 transaksiyanı tapmaq.

select t.transactionid,
       t.transactionstartdatetime,
       t.transactionenddatetime,
       t.transactionenddatetime-t.transactionstartdatetime as duration
from texas t
order by duration desc fetch first 10 rows with ties;


--6. Hər bir Tranzaksiya Tipinə Görə Ümumi Tranzaksiya Sayı və Toplam Məbləğin tapilmasi.

select dt.transactiontypename as transaction_type,
       count(t.transactionid) as transaction_count,
       sum(t.transactionamount) as transaction_amount
from dim_transaction_type dt
join texas t on dt.transactiontypeid=t.transactiontypeid
group by dt.transactiontypename;


--7. BirthDate sütununa əsasən müştəriləri yaş qruplarına ayırın və ortalama tranzaksiya məbləğini göstərin. 
-- (25 yaşdan aşağı, 25-40 yaş, 41-60 yaş ve 60 yaşdan yuxarı)


select
       case when extract(year from sysdate) - extract(year from d.birthdate) < 25 then '25 yaşdan aşağı'
            when extract(year from sysdate) - extract(year from d.birthdate) < 40 then '25-40 yaş'
            when extract(year from sysdate) - extract(year from d.birthdate) < 60 then '41-60 yaş'
            else '60 yaşdan yuxarı' end as age_group,
       avg(t.transactionamount) as avg_transaction_amount
from dim_customers d
join texas t on t.cardholderid=d.cardholderid
group by 
      case when extract(year from sysdate) - extract(year from d.birthdate) < 25 then '25 yaşdan aşağı'
            when extract(year from sysdate) - extract(year from d.birthdate) < 40 then '25-40 yaş'
            when extract(year from sysdate) - extract(year from d.birthdate) < 60 then '41-60 yaş'
            else '60 yaşdan yuxarı' end 



--8. ATMID-yə görə hər bir ATM-də yerli və qeyri-yerli müştərilərin tranzaksiya sayını göstərir.

select d.atmid,
       sum(case when d.ismegabank=1 then 1 else 0 end) as yerli,
       sum(case when d.ismegabank=0 then 1 else 0 end )as qeyri_yerli
from dim_customers d
group by d.atmid     
order by d.atmid 



--9 En cox emeliyyat kecen ilk 3 ATM-in idsi, yerlesdiyi seher ve olkeni cixartmaq.

select a.atmid, 
       sum(a.say) as total_count,
       (select dl.city
        from dim_locations dl
        where dl.locationid=a.locationid) as city,
       (select dl.country
        from dim_locations dl
        where dl.locationid=a.locationid) as country        
from 
(select  t.cardholderid as customer,
        (select dc.atmid
        from dim_customers dc
        where dc.cardholderid=t.cardholderid) as ATMid,
        t.locationid as locationid,
        count(*) as say
from texas t
group by t.locationid,t.cardholderid
order by say desc ) a
group by a.atmid,a.locationid
order by total_count desc fetch first 3 rows only;



--10. Müştəri Tiplərinə Görə Ümumi Tranzaksiya Məbləği  


select 'yerli' as tip,
       sum(t.transactionamount)
from texas t
where t.cardholderid in (select d.cardholderid
                         from dim_customers d
                         where d.ismegabank=1)
group by 'yerli'

UNION ALL

select 'qeyri_yerli' as tip,
       sum(t.transactionamount)
from texas t
where t.cardholderid in (select d.cardholderid
                         from dim_customers d
                         where d.ismegabank=0)
group by 'qeyri_yerli'                         




select 'male' as cins,
       sum(t.transactionamount)
from texas t
where t.cardholderid in (select d.cardholderid
                         from dim_customers d
                         where d.gender='M')
group by 'male'

UNION ALL

select 'female' as cins,
       sum(t.transactionamount)
from texas t
where t.cardholderid in (select d.cardholderid
                         from dim_customers d
                         where d.gender='F')
group by 'female'  


 
--11. Müştəri Adlarının Duplicated Olmadığı Üzrə Tranzaksiyalar  

select d.firstname,
       d.lastname,
       (select count(t.transactionid)
        from texas t
        where t.cardholderid=d.cardholderid)as say,
       (select sum(t.transactionamount)
        from texas t
        where t.cardholderid=d.cardholderid)as cem   
from dim_customers d
where d.cardholderid in (select t.cardholderid
                         from texas t)
and (d.firstname,d.lastname) in (select d.firstname,
                                        d.lastname                                
                                 from dim_customers d
                                 group by d.firstname, d.lastname
                                 having count(*)=1);


--12. Hər Müştəri Üçün Tranzaksiya İlinə Görə tranzaksiyalarin sayinin teyini ve en cox tranzaksiya kecmis top 10 ilin ve sayin cixarilmasi.


select t.cardholderid,
      extract(year from t.transactionenddatetime) as year_ ,
      count(t.transactionid) as transaction_count
from texas t
group by extract(year from t.transactionenddatetime),t.cardholderid
order by t.cardholderid



select extract(year from t.transactionenddatetime) as transaction_year ,
       count(t.transactionid) as transactionCount
from texas t
group by extract(year from t.transactionenddatetime)
order by transactionCount desc fetch first 10 rows only;

--13. Müştərinin Gender'ine gore ATMlerden tranzaksiya sayina uygun statistikanin cixarilmasi.


select a.gender,
       count(a.transactionid) transaction_counts,
       sum(a.transactionamount) transaction_amount
from
(select (select d.gender
        from dim_customers d
        where d.cardholderid=t.cardholderid) as gender,
        t.*
from texas t ) a
group by  a.gender



--14. Müştərilərin həftəlik tranzaksiya sayı və ortalama tranzaksiya məbləğini tapin.


select t.cardholderid,
       to_char(t.transactionenddatetime, 'IYYY-IW') as week_number,
       count(t.transactionid) as transaction_count,
       avg(t.transactionamount) as average_transaction_amount
from texas t
group by t.cardholderid, to_char(t.transactionenddatetime, 'IYYY-IW')              
order by t.cardholderid


--15. Hər Müştərinin Ən Yüksək Tranzaksiya Məbləğinin 2-ci Yüksək Məbləğdən Fərqi (yalnız iki və daha çox tranzaksiya edən müştərilər)

select a.cardholderid,
       a.max_transaction1 -a.max_transaction2 as difference 
from
(select t.cardholderid,
       t.transactionamount,
       first_value(t.transactionamount) over(partition by t.cardholderid order by t.transactionamount desc) as max_transaction1,
       lead(t.transactionamount) over(partition by t.cardholderid order by t.transactionamount desc) as max_transaction2,
       row_number() over (partition by t.cardholderid order by t.transactionamount desc) as row_num
from texas t
where t.cardholderid in (select t.cardholderid
                         from texas t
                         group by t.cardholderid                             
                         having count(*)>1)
) a
where a.row_num=1
