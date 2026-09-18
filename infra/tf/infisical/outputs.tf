# goes into every InfisicalSecret as kubernetesAuth.identityId
output "k8s_operator_identity_id" {
  value = infisical_identity.k8s_operator.id
}
