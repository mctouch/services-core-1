-- Your SQL goes here
create or replace view payment_service_api.payments as
    select 
        cp.id as id,
        cp.subscription_id as subscription_id,
        (cp.data ->> 'amount')::decimal as amount,
        cp.project_id as project_id,
        cp.status as status,
        payment_service.paid_transition_at(cp.*) as paid_at,
        cp.created_at as created_at,
        p.status as project_status,
        p.mode as project_mode,
        (cp.data ->> 'payment_method')::text as payment_method,
        (case when core.is_owner_or_admin(cp.user_id) then (cp.data ->> 'customer')::json else null::json end) as billing_data,
        (case 
            when core.is_owner_or_admin(cp.user_id) and (cp.data ->> 'payment_method')::text = 'credit_card' then 
                json_build_object(
                    'first_digits', (cp.gateway_general_data->>'card_first_digits')::text,
                    'last_digits', (cp.gateway_general_data->>'card_last_digits')::text,
                    'brand', (cp.gateway_general_data->>'card_brand')::text,
                    'country', (cp.gateway_general_data->>'card_country')::text
                )
            when core.is_owner_or_admin(cp.user_id) and (cp.data ->> 'payment_method')::text = 'boleto' then
                json_build_object(
                    'barcode', (cp.gateway_general_data->>'boleto_barcode')::text,
                    'url', (cp.gateway_general_data->>'boleto_url')::text,
                    'expiration_date', (cp.gateway_general_data->>'boleto_expiration_date')::timestamp
                )        
            else null::json end) as payment_method_details
    from payment_service.catalog_payments cp
        join project_service.projects p on p.id = cp.project_id
        join community_service.users u on u.id = cp.user_id
        where cp.platform_id = core.current_platform_id() and (core.is_owner_or_admin(cp.user_id) 
            or core.is_owner_or_admin(p.user_id))
    order by cp.id desc;
grant select on payment_service_api.payments to platform_user, scoped_user;
CREATE OR REPLACE VIEW "payment_service_api"."subscriptions" AS 
 SELECT s.id,
    s.project_id,
        CASE
            WHEN core.is_owner_or_admin(s.user_id) THEN s.credit_card_id
            ELSE NULL::bigint
        END AS credit_card_id,
        CASE
            WHEN core.is_owner_or_admin(s.user_id) THEN stats.paid_count
            ELSE NULL::bigint
        END AS paid_count,
        CASE
            WHEN core.is_owner_or_admin(s.user_id) THEN stats.total_paid
            ELSE (NULL::bigint)::numeric
        END AS total_paid,
    s.status,
    payment_service.paid_transition_at(ROW(last_paid_payment.id, last_paid_payment.platform_id, last_paid_payment.project_id, last_paid_payment.user_id, last_paid_payment.subscription_id, last_paid_payment.data, last_paid_payment.gateway, last_paid_payment.gateway_cached_data, last_paid_payment.created_at, last_paid_payment.updated_at, last_paid_payment.common_contract_data, last_paid_payment.gateway_general_data, last_paid_payment.status)) AS paid_at,
    (payment_service.paid_transition_at(ROW(last_paid_payment.id, last_paid_payment.platform_id, last_paid_payment.project_id, last_paid_payment.user_id, last_paid_payment.subscription_id, last_paid_payment.data, last_paid_payment.gateway, last_paid_payment.gateway_cached_data, last_paid_payment.created_at, last_paid_payment.updated_at, last_paid_payment.common_contract_data, last_paid_payment.gateway_general_data, last_paid_payment.status)) + '1 mon'::interval) AS next_charge_at,
    ((((s.checkout_data - 'card_id'::text) - 'card_hash'::text) - 'current_ip'::text) || jsonb_build_object('customer', (((s.checkout_data ->> 'customer'::text))::jsonb || jsonb_build_object('name', (u.data ->> 'name'::text), 'email', (u.data ->> 'email'::text), 'document_number', (u.data ->> 'document_number'::text))))) AS checkout_data,
    s.created_at
   FROM (((((payment_service.subscriptions s
     JOIN project_service.projects p ON ((p.id = s.project_id)))
     JOIN community_service.users u ON ((u.id = s.user_id)))
     LEFT JOIN LATERAL ( SELECT sum(((cp.data ->> 'amount'::text))::numeric) AS total_paid,
            count(1) FILTER (WHERE (cp.status = 'paid'::payment_service.payment_status)) AS paid_count,
            count(1) FILTER (WHERE (cp.status = 'refused'::payment_service.payment_status)) AS refused_count
           FROM payment_service.catalog_payments cp
          WHERE (cp.subscription_id = s.id)) stats ON (true))
     LEFT JOIN LATERAL ( SELECT cp.id,
            cp.platform_id,
            cp.project_id,
            cp.user_id,
            cp.subscription_id,
            cp.data,
            cp.gateway,
            cp.gateway_cached_data,
            cp.created_at,
            cp.updated_at,
            cp.common_contract_data,
            cp.gateway_general_data,
            cp.status
           FROM payment_service.catalog_payments cp
          WHERE ((cp.subscription_id = s.id) AND (cp.status = 'paid'::payment_service.payment_status))
          ORDER BY cp.id DESC
         LIMIT 1) last_paid_payment ON (true))
     LEFT JOIN LATERAL ( SELECT cp.id,
            cp.platform_id,
            cp.project_id,
            cp.user_id,
            cp.subscription_id,
            cp.data,
            cp.gateway,
            cp.gateway_cached_data,
            cp.created_at,
            cp.updated_at,
            cp.common_contract_data,
            cp.gateway_general_data,
            cp.status
           FROM payment_service.catalog_payments cp
          WHERE (cp.subscription_id = s.id)
          ORDER BY cp.id DESC
         LIMIT 1) last_payment ON (true))
  WHERE s.platform_id = core.current_platform_id() and (core.is_owner_or_admin(s.user_id) OR core.is_owner_or_admin(p.user_id));