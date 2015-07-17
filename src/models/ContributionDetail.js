var ContributionDetail = m.postgrest.model('contribution_details', [
  'id','contribution_id','user_id','project_id',
  'reward_id','payment_id','permalink','project_name','project_img',
  'user_name','user_profile_img','email','key','value',
  'installments','installment_value','state','anonymous',
  'payer_email','gateway','gateway_id','gateway_fee',
  'gateway_data','payment_method','project_state',
  'has_rewards','pending_at','paid_at','refused_at', 'reward_minimum_value',
  'pending_refund_at','refunded_at','created_at', 'is_second_slip'
]);

adminApp.models.ContributionDetail = ContributionDetail;
