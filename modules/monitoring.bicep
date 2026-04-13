@description('Resource ID of the Container App to monitor.')
param containerAppId string

@description('Name of the Container App (used in alert naming).')
param containerAppName string

resource alert5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-5xx-${containerAppName}'
  location: 'global'
  properties: {
    description: 'Fires when HTTP 5xx errors exceed 5 requests in a 15-minute window.'
    severity: 2
    enabled: true
    scopes: [
      containerAppId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'High5xxRate'
          metricNamespace: 'Microsoft.App/containerApps'
          metricName: 'Requests'
          dimensions: [
            {
              name: 'statusCodeCategory'
              operator: 'Include'
              values: [
                '5xx'
              ]
            }
          ]
          timeAggregation: 'Total'
          operator: 'GreaterThan'
          threshold: 5
        }
      ]
    }
    actions: []
  }
}

output alertRuleId string = alert5xx.id
