define([
    'backbone',
    'collections/newrelic-charts',
    'views/widget-view',
    'text!templates/github.html.haml'
], function (Backbone, PerformanceCharts, WidgetView, template) {
    return Backbone.SuperView.extend({

    id: 'github-view',

    className: 'row',

    template: template,

    initialize: function (options) {
      this.performanceModel = new PerformanceCharts();
      this.performanceModel.on('reset', function () {
        this.renderPerformanceChart();
      }, this);
    },

    postRender: function () {
      this.performanceView = new WidgetView({
       heading: 'Performance',
       contentId: 'performance-widget'
      }).render();
      this.$('.performance-widget').append(this.performanceView.el);
      this.performanceModel.fetch();
    },

    renderPerformanceChart: function () {
      if (this.performanceModel.size() > 0) {
        this.performanceView.append(this.renderChart(this.performanceModel.first()));
      } else {
        this.performanceView.append('New Relic needs to be configured from the Performance Tab. The first graph added will appear here.');
      }
    },

    renderChart: function (chart) {
      return chart.get('source');
      }
  });
});
